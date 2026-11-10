import Foundation

public struct ImportIssue: Identifiable, Sendable {
  public let id = UUID()
  public let position: Int
  public let reason: String
}

public struct ImportPreview: Sendable {
  public let accounts: [OTPAccount]
  public let issues: [ImportIssue]
  public init(accounts: [OTPAccount], issues: [ImportIssue]) {
    self.accounts = accounts
    self.issues = issues
  }
}

public enum BackupImporter {
  public static let maximumBytes = 5 * 1024 * 1024

  public static func parse(_ data: Data, password: String? = nil) throws -> ImportPreview {
    guard data.count <= maximumBytes else { throw AuthError.invalid(L10n.text("备份文件超过 5 MB，无法导入。")) }
    guard let raw = String(data: data, encoding: .utf8) else {
      throw AuthError.invalid(L10n.text("备份不是 UTF-8 文本文件。"))
    }
    let text = raw.trimmingCharacters(
      in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
    guard !text.isEmpty else { throw AuthError.emptyBackup }
    if text.hasPrefix("{") || text.hasPrefix("[") {
      guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) else {
        throw AuthError.invalid(L10n.text("JSON 备份格式错误，请重新从插件导出。"))
      }
      if let dictionary = object as? [String: Any], dictionary["format"] as? String == "quickauth" {
        let plaintext = try BackupExporter.decrypt(Data(text.utf8), password: password)
        guard let records = try? JSONSerialization.jsonObject(with: plaintext) else {
          throw AuthError.decryptionFailed
        }
        return try parseJSON(records, password: nil)
      }
      return try parseJSON(object, password: password)
    }
    var accounts: [OTPAccount] = []
    var issues: [ImportIssue] = []
    let lines = text.components(separatedBy: .newlines)
    guard lines.count <= 10000 else { throw AuthError.invalid(L10n.text("备份中的行数过多。")) }
    for (index, line) in lines.enumerated() {
      let value = line.trimmingCharacters(in: .whitespaces)
      if value.isEmpty || value.hasPrefix("#") { continue }
      do { accounts.append(try parseURI(value)) } catch {
        issues.append(.init(position: index + 1, reason: error.localizedDescription))
      }
    }
    guard !accounts.isEmpty || !issues.isEmpty else { throw AuthError.emptyBackup }
    return ImportPreview(accounts: accounts, issues: issues)
  }

  public static func parseURI(_ uri: String) throws -> OTPAccount {
    guard let url = URLComponents(string: uri), url.scheme?.lowercased() == "otpauth",
      let host = url.host?.lowercased(), ["totp", "hotp", "steam"].contains(host)
    else {
      throw AuthError.invalid(L10n.text("不是支持的 otpauth 账户链接。"))
    }
    var values: [String: String] = [:]
    for item in url.queryItems ?? [] {
      let name = item.name.lowercased()
      guard values[name] == nil, let value = item.value else {
        throw AuthError.invalid(L10n.text("账户链接含重复或空参数。"))
      }
      values[name] = value
    }
    guard let secret = values["secret"], !secret.isEmpty else {
      throw AuthError.invalid(L10n.text("账户链接缺少密钥。"))
    }
    var label = url.path
    if label.hasPrefix("/") { label.removeFirst() }
    let parts = label.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    let labelIssuer = parts.count == 2 ? String(parts[0]) : ""
    let account = parts.count == 2 ? String(parts[1]) : label
    let issuer = values["issuer"] ?? labelIssuer
    let encoder = values["encoder"]?.lowercased()
    guard encoder == nil || encoder == "steam" else { throw AuthError.invalid(L10n.text("不支持此验证码编码方式。")) }
    let kind: OTPKind =
      host == "hotp" ? .hotp : (host == "steam" || encoder == "steam" ? .steam : .totp)
    var record: [String: Any] = [
      "type": kind.rawValue, "issuer": issuer, "account": account, "secret": secret,
    ]
    for name in ["algorithm", "digits", "period", "counter"] {
      if let value = values[name] { record[name] = value }
    }
    if host == "hotp" && values["counter"] == nil { throw AuthError.invalid(L10n.text("HOTP 账户缺少计数器。")) }
    return try parseRecord(record)
  }

  private static func parseJSON(_ object: Any, password: String?) throws -> ImportPreview {
    var records: [(String, Any)]
    var root: [String: Any] = [:]
    if let array = object as? [Any] {
      records = array.enumerated().map { (String($0.offset), $0.element) }
    } else if let dictionary = object as? [String: Any] {
      root = dictionary
      if dictionary["secret"] != nil {
        records = [("0", dictionary)]
      } else {
        records = dictionary.filter {
          !["key", "enc", "hash", "UserSettings", "LocalStorage"].contains($0.key)
        }.map { ($0.key, $0.value) }
      }
    } else {
      throw AuthError.emptyBackup
    }
    records = records.filter { ($0.1 as? [String: Any])?["dataType"] as? String != "Key" }
    guard records.count <= 5000 else { throw AuthError.invalid(L10n.text("一次最多导入 5000 个账户。")) }
    records.sort {
      let left = ($0.1 as? [String: Any])?["index"] as? Int ?? Int($0.0) ?? Int.max
      let right = ($1.1 as? [String: Any])?["index"] as? Int ?? Int($1.0) ?? Int.max
      return left == right ? $0.0 < $1.0 : left < right
    }
    let encrypted = records.contains {
      guard let record = $0.1 as? [String: Any] else { return false }
      return record["encrypted"] as? Bool == true
        || record["dataType"] as? String == "EncOTPStorage"
    }
    if encrypted && (password == nil || password!.isEmpty) { throw AuthError.passwordRequired }
    var oldPassphrase = password ?? ""
    let oldKey = root["key"] as? [String: Any] ?? (root["enc"] != nil ? root : [:])
    if encrypted, let wrapped = oldKey["enc"] as? String {
      let key = try BackupCrypto.decrypt(wrapped, password: oldPassphrase)
      oldPassphrase = key.map { String(format: "%02x", $0) }.joined()
    }
    var unlockedKeys: [String: String] = [:]
    var accounts: [OTPAccount] = []
    var issues: [ImportIssue] = []
    for (position, pair) in records.enumerated() {
      guard var record = pair.1 as? [String: Any] else {
        issues.append(.init(position: position + 1, reason: L10n.text("无法识别此记录。")))
        continue
      }
      // Any decryption failure aborts the preview; never silently import a subset
      // of a backup with a wrong password or a missing encryption key.
      if record["dataType"] as? String == "EncOTPStorage" {
        guard let keyID = record["keyId"] as? String, let key = root[keyID] as? [String: Any],
          key["dataType"] as? String == "Key", key["id"] as? String == keyID,
          let ciphertext = record["data"] as? String
        else { throw AuthError.decryptionFailed }
        if unlockedKeys[keyID] == nil {
          unlockedKeys[keyID] = try BackupCrypto.unlockKey(key, password: password ?? "")
        }
        let plaintext = try BackupCrypto.decrypt(ciphertext, password: unlockedKeys[keyID]!)
        guard let decrypted = try? JSONSerialization.jsonObject(with: plaintext) as? [String: Any],
          decrypted["secret"] is String
        else { throw AuthError.decryptionFailed }
        record = decrypted
        record["encrypted"] = false
      } else if record["encrypted"] as? Bool == true {
        guard let ciphertext = record["secret"] as? String,
          let secret = String(
            data: try BackupCrypto.decrypt(ciphertext, password: oldPassphrase), encoding: .utf8),
          !secret.isEmpty
        else { throw AuthError.decryptionFailed }
        record["secret"] = secret
        record["encrypted"] = false
      }
      do { accounts.append(try parseRecord(record)) } catch {
        issues.append(.init(position: position + 1, reason: error.localizedDescription))
      }
    }
    guard !accounts.isEmpty || !issues.isEmpty else { throw AuthError.emptyBackup }
    return ImportPreview(accounts: accounts, issues: issues)
  }

  private static func parseRecord(_ record: [String: Any]) throws -> OTPAccount {
    for field in ["type", "algorithm", "counter"] {
      if let number = record[field] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
        throw AuthError.invalid(L10n.text("账户参数 \(field) 格式错误。"))
      }
    }
    let types = [1: "totp", 2: "hotp", 3: "battle", 4: "steam", 5: "hex", 6: "hhex"]
    var type =
      (record["type"] as? String)?.lowercased() ?? (record["type"] as? Int).flatMap { types[$0] }
      ?? "totp"
    if record["type"] != nil && !(record["type"] is String)
      && (record["type"] as? Int).flatMap({ types[$0] }) == nil
    {
      throw AuthError.invalid(L10n.text("不支持此账户类型。"))
    }
    guard var secretText = record["secret"] as? String else { throw AuthError.invalid(L10n.text("账户缺少密钥。")) }
    for (prefix, value) in [("stm-", "steam"), ("blz-", "battle"), ("bliz-", "battle")] {
      if secretText.hasPrefix(prefix) {
        secretText = String(secretText.dropFirst(prefix.count))
        type = value
        break
      }
    }
    guard ["totp", "hotp", "battle", "steam", "hex", "hhex"].contains(type) else {
      throw AuthError.invalid(L10n.text("不支持此账户类型。"))
    }
    let algorithm: OTPAlgorithm
    if let value = record["algorithm"] as? Int {
      guard let parsed = [1: OTPAlgorithm.sha1, 2: .sha256, 3: .sha512][value] else {
        throw AuthError.invalid(L10n.text("不支持此哈希算法（如 GOST）。"))
      }
      algorithm = parsed
    } else if let value = record["algorithm"] as? String {
      guard
        let parsed = OTPAlgorithm(
          rawValue: value.uppercased().replacingOccurrences(of: "-", with: ""))
      else {
        throw AuthError.invalid(L10n.text("不支持此哈希算法（如 GOST）。"))
      }
      algorithm = parsed
    } else if record["algorithm"] == nil {
      algorithm = .sha1
    } else {
      throw AuthError.invalid(L10n.text("哈希算法格式错误。"))
    }
    func integer(_ field: String, fallback: Int) throws -> Int {
      guard let value = record[field] else { return fallback }
      let text: String
      if let string = value as? String {
        text = string
      } else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
        text = number.stringValue
      } else {
        throw AuthError.invalid(L10n.text("账户参数 \(field) 格式错误。"))
      }
      guard let result = Int(text) else { throw AuthError.invalid(L10n.text("账户参数 \(field) 必须是整数。")) }
      return result
    }
    let parsedDigits = try integer("digits", fallback: 6)
    let digits = type == "battle" ? 8 : (type == "steam" ? 6 : parsedDigits)
    let period = try integer("period", fallback: 30)
    let counter: UInt64
    if let value = record["counter"] {
      let text = (value as? String) ?? (value as? NSNumber)?.stringValue ?? ""
      guard let parsed = UInt64(text) else { throw AuthError.invalid(L10n.text("HOTP 计数器格式错误。")) }
      counter = parsed
    } else {
      counter = 0
    }
    let kind: OTPKind =
      ["hotp", "hhex"].contains(type) ? .hotp : (type == "steam" ? .steam : .totp)
    let secret =
      try ["hex", "hhex"].contains(type) ? Base32.decodeHex(secretText) : Base32.decode(secretText)
    return try OTPAccount(
      issuer: record["issuer"] as? String ?? "", account: record["account"] as? String ?? "",
      secret: secret, kind: kind, algorithm: algorithm, digits: digits,
      period: period, counter: counter, favorite: record["pinned"] as? Bool ?? false)
  }
}
