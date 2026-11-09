import Security
import XCTest

@testable import QuickAuthCore

final class VaultTests: XCTestCase {
  func testKeychainRoundTripAndUpdate() throws {
    guard ProcessInfo.processInfo.environment["QUICKAUTH_TEST_KEYCHAIN"] == "1" else {
      throw XCTSkip("Set QUICKAUTH_TEST_KEYCHAIN=1 to exercise a temporary Keychain item.")
    }
    let service = "local.quickauth.tests.\(UUID().uuidString)"
    let vault = KeychainVault(service: service)
    defer {
      SecItemDelete(
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
          as CFDictionary)
    }
    XCTAssertTrue(try vault.load().isEmpty)
    var account = try OTPAccount(
      issuer: "Synthetic Test", account: "test@example.com", secret: Data("public-test-only".utf8))
    try vault.save([account])
    XCTAssertEqual(try vault.load(), [account])
    account.favorite = true
    try vault.save([account])
    XCTAssertEqual(try vault.load(), [account])
    try vault.save([])
    XCTAssertTrue(try vault.load().isEmpty)
  }
}
