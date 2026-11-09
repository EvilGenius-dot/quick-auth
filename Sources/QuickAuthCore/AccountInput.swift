import Foundation

public struct AccountInput: Equatable {
  public var issuer = ""
  public var account = ""
  public var secret = ""
  public var hexadecimal = false
  public var kind: OTPKind = .totp
  public var algorithm: OTPAlgorithm = .sha1
  public var digits = 6
  public var period = "30"
  public var counter = "0"

  public init() {}

  public func makeAccount() throws -> OTPAccount {
    let issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
    let account = account.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !issuer.isEmpty || !account.isEmpty else { throw AuthError.invalid("请填写服务名称或账号。") }
    guard let interval = kind == .hotp ? 30 : Int(period), (1...86400).contains(interval) else {
      throw AuthError.invalid("刷新周期应为 1–86400 秒的整数。")
    }
    guard let counter = kind == .hotp ? UInt64(counter) : 0 else {
      throw AuthError.invalid("计数器应为非负整数。")
    }
    let data = try hexadecimal ? Base32.decodeHex(secret) : Base32.decode(secret)
    return try OTPAccount(
      issuer: issuer, account: account, secret: data, kind: kind,
      algorithm: algorithm, digits: kind == .steam ? 6 : digits,
      period: kind == .hotp ? 30 : interval,
      counter: kind == .hotp ? counter : 0)
  }
}
