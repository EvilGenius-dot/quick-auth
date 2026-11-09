import CryptoKit
import Foundation

public enum AuthError: LocalizedError, Equatable {
  case invalid(String)
  case passwordRequired
  case decryptionFailed
  case emptyBackup

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    case .passwordRequired: return "这是密码保护备份，请输入导出时设置的备份密码。"
    case .decryptionFailed: return "密码不正确，或加密备份已损坏。请检查密码和原始文件后重试。"
    case .emptyBackup: return "备份中没有找到可导入的账户。请选择 Authenticator 导出的 JSON 或 TXT 文件。"
    }
  }
}

public enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
  case sha1 = "SHA1"
  case sha256 = "SHA256"
  case sha512 = "SHA512"
}

public enum OTPKind: String, Codable, Sendable {
  case totp, hotp, steam
}

public struct OTPAccount: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var issuer: String
  public var account: String
  public var secret: Data
  public var kind: OTPKind
  public var algorithm: OTPAlgorithm
  public var digits: Int
  public var period: Int
  public var counter: UInt64
  public var favorite: Bool

  public init(
    id: UUID = UUID(), issuer: String, account: String, secret: Data,
    kind: OTPKind = .totp, algorithm: OTPAlgorithm = .sha1,
    digits: Int = 6, period: Int = 30, counter: UInt64 = 0, favorite: Bool = false
  ) throws {
    self.id = id
    self.issuer = issuer
    self.account = account
    self.secret = secret
    self.kind = kind
    self.algorithm = algorithm
    self.digits = digits
    self.period = period
    self.counter = counter
    self.favorite = favorite
    try validate()
  }

  public func validate() throws {
    guard !secret.isEmpty, secret.count <= 1024 else { throw AuthError.invalid("密钥为空或过长。") }
    guard (6...10).contains(digits) else { throw AuthError.invalid("不支持的验证码位数（支持 6–10 位）。") }
    guard (1...86400).contains(period) else { throw AuthError.invalid("验证码周期必须在 1–86400 秒之间。") }
    guard issuer.count <= 512, account.count <= 512 else { throw AuthError.invalid("账户名称过长。") }
  }

  public var title: String { issuer.isEmpty ? (account.isEmpty ? "未命名账户" : account) : issuer }
  public var subtitle: String { issuer.isEmpty ? "身份验证器" : (account.isEmpty ? "未命名账户" : account) }

  // Counter is intentionally excluded: importing an old HOTP backup must never rewind it.
  public var fingerprint: String {
    let components = [
      secret.base64EncodedString(), kind.rawValue, algorithm.rawValue,
      String(digits), String(period),
    ]
    return SHA256.hash(data: Data(components.joined(separator: "|").utf8))
      .map { String(format: "%02x", $0) }.joined()
  }

  public func matches(_ query: String) -> Bool {
    let terms = query.split(whereSeparator: \.isWhitespace)
    let text = "\(issuer) \(account)"
    return terms.allSatisfy { text.localizedStandardContains(String($0)) }
  }

  public func code(at date: Date = Date()) -> String {
    let step =
      kind == .hotp ? counter : UInt64(max(0, floor(date.timeIntervalSince1970 / Double(period))))
    var bigEndian = step.bigEndian
    let message = withUnsafeBytes(of: &bigEndian) { Data($0) }
    let key = SymmetricKey(data: secret)
    let digest: [UInt8]
    switch algorithm {
    case .sha1: digest = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
    case .sha256: digest = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
    case .sha512: digest = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
    }
    let offset = Int(digest[digest.count - 1] & 15)
    var number =
      digest[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } & 0x7fff_ffff
    if kind == .steam {
      let alphabet = Array("23456789BCDFGHJKMNPQRTVWXY")
      return String(
        (0..<5).map { _ in
          let character = alphabet[Int(number % UInt32(alphabet.count))]
          number /= UInt32(alphabet.count)
          return character
        })
    }
    let modulus = (0..<digits).reduce(UInt64(1)) { value, _ in value * 10 }
    return String(format: "%0*llu", digits, UInt64(number) % modulus)
  }

  public func remaining(at date: Date) -> Int {
    period
      - Int(
        max(0, floor(date.timeIntervalSince1970)).truncatingRemainder(dividingBy: Double(period)))
  }
}

public enum Base32 {
  public static func encode(_ data: Data) -> String {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
    var output: [UInt8] = []
    var buffer: UInt32 = 0
    var bits = 0
    for byte in data {
      buffer = (buffer << 8) | UInt32(byte)
      bits += 8
      while bits >= 5 {
        bits -= 5
        output.append(alphabet[Int((buffer >> bits) & 31)])
      }
      buffer &= (1 << bits) - 1
    }
    if bits > 0 { output.append(alphabet[Int((buffer << (5 - bits)) & 31)]) }
    return String(decoding: output, as: UTF8.self)
  }

  public static func decode(_ input: String) throws -> Data {
    let normalized = input.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    let parts = normalized.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    let body = String(parts[0])
    let padding = normalized.count - body.count
    let remainders = [0: 0, 2: 6, 4: 4, 5: 3, 7: 1]
    guard let required = remainders[body.count % 8], !body.isEmpty,
      padding == 0 || (padding == required && normalized.suffix(padding).allSatisfy({ $0 == "=" }))
    else {
      throw AuthError.invalid("密钥不是有效的 Base32 文本。")
    }
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
    var buffer: UInt32 = 0
    var bits = 0
    var bytes = Data()
    for byte in body.utf8 {
      guard let value = alphabet.firstIndex(of: byte) else { throw AuthError.invalid("密钥包含无效字符。") }
      buffer = (buffer << 5) | UInt32(value)
      bits += 5
      if bits >= 8 {
        bits -= 8
        bytes.append(UInt8((buffer >> bits) & 255))
      }
      buffer &= (1 << bits) - 1
    }
    guard buffer == 0, !bytes.isEmpty else { throw AuthError.invalid("密钥长度或末尾填充无效。") }
    return bytes
  }

  public static func decodeHex(_ input: String) throws -> Data {
    let text = input.filter { !$0.isWhitespace }
    guard !text.isEmpty, text.count % 2 == 0 else { throw AuthError.invalid("十六进制密钥长度无效。") }
    var bytes = Data()
    var index = text.startIndex
    while index < text.endIndex {
      let end = text.index(index, offsetBy: 2)
      guard let byte = UInt8(text[index..<end], radix: 16) else {
        throw AuthError.invalid("十六进制密钥包含无效字符。")
      }
      bytes.append(byte)
      index = end
    }
    return bytes
  }
}

public struct ImportMerge: Sendable {
  public let accounts: [OTPAccount]
  public let added: Int
  public let duplicates: Int

  public init(existing: [OTPAccount], incoming: [OTPAccount]) {
    var result = existing
    var known = Set(existing.map(\.fingerprint))
    var duplicates = 0
    for account in incoming {
      if known.insert(account.fingerprint).inserted {
        result.append(account)
      } else {
        duplicates += 1
      }
    }
    self.accounts = result
    self.added = result.count - existing.count
    self.duplicates = duplicates
  }
}
