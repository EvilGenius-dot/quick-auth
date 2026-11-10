import CommonCrypto
import CryptoKit
import Foundation
import Security

public enum BackupExporter {
  public static func plaintext(_ accounts: [OTPAccount]) throws -> Data {
    guard !accounts.isEmpty else { throw AuthError.emptyBackup }
    guard accounts.count <= 5000 else { throw AuthError.invalid(L10n.text("一次最多导出 5000 个账户。")) }
    var records: [String: Any] = [:]
    for (index, account) in accounts.enumerated() {
      try account.validate()
      records[account.id.uuidString] = [
        "dataType": "OTPStorage", "hash": account.id.uuidString, "index": index,
        "type": account.kind.rawValue, "issuer": account.issuer, "account": account.account,
        "secret": Base32.encode(account.secret), "algorithm": account.algorithm.rawValue,
        "digits": account.digits, "period": account.period,
        "counter": account.counter, "pinned": account.favorite, "encrypted": false,
      ]
    }
    let data = try JSONSerialization.data(
      withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
    guard data.count <= BackupImporter.maximumBytes else { throw AuthError.invalid(L10n.text("备份过大，无法导出。")) }
    return data
  }

  public static func encrypted(_ accounts: [OTPAccount], password: String) throws -> Data {
    guard password.count >= 8, password.utf8.count <= 4096 else {
      throw AuthError.invalid(L10n.text("备份密码至少需要 8 个字符，且不能超过 4096 字节。"))
    }
    let plaintext = try plaintext(accounts)
    var salt = Data(count: 16)
    let status = salt.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
    }
    guard status == errSecSuccess else { throw AuthError.invalid(L10n.text("无法生成安全随机数，导出已取消。")) }
    let key = try derive(password: password, salt: salt, iterations: iterations)
    let ciphertext = try AES.GCM.seal(plaintext, using: key, authenticating: context)
    guard let combined = ciphertext.combined else { throw AuthError.invalid(L10n.text("无法加密备份。")) }
    let envelope = EncryptedBackup(
      format: "quickauth", version: 1, kdf: "PBKDF2-SHA256",
      iterations: iterations, salt: salt, cipher: "AES-256-GCM", data: combined)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let output = try encoder.encode(envelope)
    guard output.count <= BackupImporter.maximumBytes else {
      throw AuthError.invalid(L10n.text("加密备份超过 5 MB，无法导出。"))
    }
    return output
  }

  static func decrypt(_ data: Data, password: String?) throws -> Data {
    guard let envelope = try? JSONDecoder().decode(EncryptedBackup.self, from: data),
      envelope.format == "quickauth", envelope.version == 1,
      envelope.kdf == "PBKDF2-SHA256", envelope.cipher == "AES-256-GCM",
      (100000...2_000_000).contains(envelope.iterations), envelope.salt.count == 16,
      envelope.data.count >= 28
    else { throw AuthError.invalid(L10n.text("不支持或已损坏的 Quick Auth 加密备份。")) }
    guard let password, !password.isEmpty else { throw AuthError.passwordRequired }
    guard password.utf8.count <= 4096 else { throw AuthError.decryptionFailed }
    do {
      let key = try derive(password: password, salt: envelope.salt, iterations: envelope.iterations)
      return try AES.GCM.open(
        AES.GCM.SealedBox(combined: envelope.data), using: key, authenticating: context)
    } catch { throw AuthError.decryptionFailed }
  }

  private static let iterations = 600000
  private static let context = Data("QuickAuth backup v1".utf8)
  private struct EncryptedBackup: Codable {
    let format: String
    let version: Int
    let kdf: String
    let iterations: Int
    let salt: Data
    let cipher: String
    let data: Data
  }
  private static func derive(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
    let passwordBytes = Array(password.utf8)
    var result = Data(count: 32)
    let status = result.withUnsafeMutableBytes { output in
      passwordBytes.withUnsafeBufferPointer { passwordBuffer in
        salt.withUnsafeBytes { saltBytes in
          CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            UnsafeRawPointer(passwordBuffer.baseAddress!).assumingMemoryBound(to: Int8.self),
            passwordBytes.count,
            saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
            output.bindMemory(to: UInt8.self).baseAddress, 32)
        }
      }
    }
    guard status == kCCSuccess else { throw AuthError.decryptionFailed }
    return SymmetricKey(data: result)
  }
}
