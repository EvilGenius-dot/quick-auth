import XCTest

@testable import QuickAuthCore

final class ExportAndInputTests: XCTestCase {
  let password = "虚构测试-password-2026"
  func accounts() throws -> [OTPAccount] {
    try [
      OTPAccount(
        issuer: "测试服务", account: "test@example.com", secret: Data([1, 2, 3, 4, 5]),
        algorithm: .sha512, digits: 8, period: 60, favorite: true),
      OTPAccount(
        issuer: "HOTP", account: "example", secret: Data("public-fixture-1".utf8), kind: .hotp,
        counter: 1234),
      OTPAccount(
        issuer: "Steam", account: "example", secret: Data("public-fixture-2".utf8), kind: .steam),
    ]
  }

  func assertEquivalent(
    _ actual: [OTPAccount], _ expected: [OTPAccount], file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(actual.count, expected.count, file: file, line: line)
    for (a, b) in zip(actual, expected) {
      XCTAssertEqual(a.fingerprint, b.fingerprint, file: file, line: line)
      XCTAssertEqual(a.counter, b.counter, file: file, line: line)
      XCTAssertEqual(a.issuer, b.issuer, file: file, line: line)
      XCTAssertEqual(a.account, b.account, file: file, line: line)
      XCTAssertEqual(a.favorite, b.favorite, file: file, line: line)
    }
  }

  func testPlaintextExportRoundTrip() throws {
    let accounts = try accounts()
    let preview = try BackupImporter.parse(BackupExporter.plaintext(accounts))
    XCTAssertTrue(preview.issues.isEmpty)
    assertEquivalent(preview.accounts, accounts)
  }

  func testEncryptedExportRoundTripAndDoesNotExposeAccounts() throws {
    let accounts = try accounts()
    let data = try BackupExporter.encrypted(accounts, password: password)
    let text = String(decoding: data, as: UTF8.self)
    XCTAssertFalse(text.contains("test@example.com"))
    XCTAssertFalse(text.contains(Base32.encode(accounts[0].secret)))
    let preview = try BackupImporter.parse(data, password: password)
    XCTAssertTrue(preview.issues.isEmpty)
    assertEquivalent(preview.accounts, accounts)
  }

  func testFreshSaltAndNonceAndIncorrectPassword() throws {
    let accounts = try accounts()
    let first = try BackupExporter.encrypted(accounts, password: password)
    let second = try BackupExporter.encrypted(accounts, password: password)
    XCTAssertNotEqual(first, second)
    XCTAssertThrowsError(try BackupImporter.parse(first)) {
      XCTAssertEqual($0 as? AuthError, .passwordRequired)
    }
    XCTAssertThrowsError(try BackupImporter.parse(first, password: "wrong")) {
      XCTAssertEqual($0 as? AuthError, .decryptionFailed)
    }
  }

  func testCiphertextTamperingAndUnsafeKDFRejected() throws {
    let data = try BackupExporter.encrypted(accounts(), password: password)
    var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var encrypted = try XCTUnwrap(Data(base64Encoded: root["data"] as? String ?? ""))
    encrypted[encrypted.count - 1] ^= 1
    root["data"] = encrypted.base64EncodedString()
    XCTAssertThrowsError(
      try BackupImporter.parse(JSONSerialization.data(withJSONObject: root), password: password))
    root["iterations"] = Int.max
    XCTAssertThrowsError(
      try BackupImporter.parse(JSONSerialization.data(withJSONObject: root), password: password))
  }

  func testInvalidExportParameters() throws {
    XCTAssertThrowsError(try BackupExporter.encrypted(accounts(), password: "short"))
    XCTAssertThrowsError(try BackupExporter.plaintext([]))
  }

  func testBase32EncodingRoundTripsArbitraryBytes() throws {
    for length in 1...100 {
      let data = Data((0..<length).map { UInt8(($0 * 31 + 7) % 256) })
      XCTAssertEqual(try Base32.decode(Base32.encode(data)), data)
    }
  }

  func testManualDefaultsAndExplicitHOTP() throws {
    var input = AccountInput()
    input.issuer = "Example"
    input.secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    let totp = try input.makeAccount()
    XCTAssertEqual(totp.code(at: Date(timeIntervalSince1970: 59)), "287082")
    input.kind = .hotp
    input.counter = "9"
    input.period = "unused"
    XCTAssertEqual(try input.makeAccount().code(), "520489")
  }

  func testManualInputRejectsInvalidParametersAndNormalizesSteam() throws {
    var input = AccountInput()
    XCTAssertThrowsError(try input.makeAccount())
    input.issuer = "Example"
    input.secret = "invalid!"
    XCTAssertThrowsError(try input.makeAccount())
    input.secret = "3132333435363738393031323334353637383930"
    input.hexadecimal = true
    input.period = "0"
    XCTAssertThrowsError(try input.makeAccount())
    input.period = "30"
    input.kind = .steam
    input.digits = 8
    XCTAssertEqual(try input.makeAccount().digits, 6)
    input.kind = .hotp
    input.counter = "-1"
    XCTAssertThrowsError(try input.makeAccount())
  }

  func testBackupFileUsesPrivatePermissionsAndAtomicReplacement() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("synthetic-backup.json")
    try BackupFileWriter.write(Data("old-test".utf8), to: file)
    try BackupFileWriter.write(Data("new-test".utf8), to: file)
    XCTAssertEqual(try Data(contentsOf: file), Data("new-test".utf8))
    let permissions =
      try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
    XCTAssertEqual(permissions?.intValue, 0o600)
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: directory.path), ["synthetic-backup.json"]
    )
  }
}
