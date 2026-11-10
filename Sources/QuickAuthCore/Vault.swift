import Foundation
import Security

public protocol VaultStorage {
  func load() throws -> [OTPAccount]
  func save(_ accounts: [OTPAccount]) throws
}

public struct KeychainVault: VaultStorage {
  private let service: String
  public init(service: String = "local.quickauth.vault") { self.service = service }

  private var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service, kSecAttrAccount as String: "accounts-v1",
      kSecAttrSynchronizable as String: false,
    ]
  }

  public func load() throws -> [OTPAccount] {
    var query = query
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return [] }
    guard status == errSecSuccess else { throw VaultError(status: status) }
    guard let data = result as? Data,
      let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
      envelope.version == 1
    else { throw AuthError.invalid(L10n.text("钥匙串中的账户数据无法读取。为保护原数据，已暂停写入。")) }
    try envelope.accounts.forEach { try $0.validate() }
    guard Set(envelope.accounts.map(\.id)).count == envelope.accounts.count else {
      throw AuthError.invalid(L10n.text("账户数据存在重复标识，已暂停写入。"))
    }
    return envelope.accounts
  }

  public func save(_ accounts: [OTPAccount]) throws {
    try accounts.forEach { try $0.validate() }
    let data = try JSONEncoder().encode(Envelope(version: 1, accounts: accounts))
    let status = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrLabel as String] = L10n.text("Quick Auth · 身份验证账户")
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      let added = SecItemAdd(item as CFDictionary, nil)
      guard added == errSecSuccess else { throw VaultError(status: added) }
    } else if status != errSecSuccess {
      throw VaultError(status: status)
    }
  }

  private struct Envelope: Codable {
    let version: Int
    let accounts: [OTPAccount]
  }
}

public struct VaultError: LocalizedError {
  public let status: OSStatus
  public var errorDescription: String? {
    L10n.text("无法访问系统钥匙串（\(status)）。请解锁登录钥匙串或允许 Quick Auth 访问后重试。")
  }
}
