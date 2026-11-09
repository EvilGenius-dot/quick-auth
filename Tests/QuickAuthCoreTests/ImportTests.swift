import XCTest

@testable import QuickAuthCore

final class ImportTests: XCTestCase {
  let password = "quick-auth-test-密码"
  let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
  func fixture(_ name: String) throws -> Data {
    try Data(
      contentsOf: XCTUnwrap(
        Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
  }
  func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

  func testPlainExtensionBackup() throws {
    let result = try BackupImporter.parse(fixture("plain"))
    XCTAssertEqual(result.accounts.count, 1)
    XCTAssertTrue(result.issues.isEmpty)
    XCTAssertEqual(result.accounts[0].title, "Fixture 测试")
    XCTAssertEqual(result.accounts[0].code(at: Date(timeIntervalSince1970: 59)), "94287082")
  }

  func testActualCryptoJSLegacyAndArgon2BrowserBackups() throws {
    for version in 1...3 {
      let result = try BackupImporter.parse(fixture("encrypted-v\(version)"), password: password)
      XCTAssertEqual(result.accounts.count, 1)
      XCTAssertTrue(result.issues.isEmpty)
      XCTAssertEqual(result.accounts[0].secret, Data("12345678901234567890".utf8))
      XCTAssertEqual(result.accounts[0].code(at: Date(timeIntervalSince1970: 59)), "94287082")
    }
  }

  func testEncryptedBackupsRequestPassword() throws {
    for version in 1...3 {
      XCTAssertThrowsError(try BackupImporter.parse(fixture("encrypted-v\(version)"))) {
        XCTAssertEqual($0 as? AuthError, .passwordRequired)
      }
    }
  }

  func testWrongPasswordNeverProducesPartialSuccess() throws {
    for version in 1...3 {
      XCTAssertThrowsError(
        try BackupImporter.parse(fixture("encrypted-v\(version)"), password: "wrong")
      ) {
        XCTAssertEqual($0 as? AuthError, .decryptionFailed)
      }
    }
  }

  func testMissingKeyAndCorruptCiphertext() throws {
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: fixture("encrypted-v3")) as? [String: Any])
    root.removeValue(forKey: "fixture-key")
    XCTAssertThrowsError(try BackupImporter.parse(json(root), password: password))
    root = ["a": ["encrypted": true, "secret": "garbage", "type": "totp"]]
    XCTAssertThrowsError(try BackupImporter.parse(json(root), password: password))
  }

  func testMaliciousArgonParametersAreRejected() throws {
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: fixture("encrypted-v3")) as? [String: Any])
    var key = try XCTUnwrap(root["fixture-key"] as? [String: Any])
    key["hash"] = "$argon2id$v=19$m=4294967295,t=999999,p=255$c2FsdHNhbHQ$aGFzaA"
    root["fixture-key"] = key
    XCTAssertThrowsError(try BackupImporter.parse(json(root), password: password))
  }

  func testV2LegacyCloudKeyLocation() throws {
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: fixture("encrypted-v2")) as? [String: Any])
    let key = try XCTUnwrap(root.removeValue(forKey: "key") as? [String: Any])
    root["enc"] = key["enc"]
    root["hash"] = key["hash"]
    XCTAssertEqual(try BackupImporter.parse(json(root), password: password).accounts.count, 1)
  }

  func testURIUnicodeLabelParametersAndBOM() throws {
    let text =
      "\u{FEFF}otpauth://totp/GitHub%3Atest%40example.com?secret=\(secret)&issuer=GitHub&algorithm=SHA256&digits=8&period=60\r\n"
    let result = try BackupImporter.parse(Data(text.utf8))
    let account = try XCTUnwrap(result.accounts.first)
    XCTAssertEqual(account.account, "test@example.com")
    XCTAssertEqual(account.issuer, "GitHub")
    XCTAssertEqual(account.period, 60)
    XCTAssertEqual(account.digits, 8)
    XCTAssertEqual(account.algorithm, .sha256)
  }

  func testInvalidLinesAreVisibleAndNeverBecomeDefaultAccounts() throws {
    let text =
      "otpauth://totp/Good?secret=\(secret)\ninvalid\notpauth://totp/Bad?secret=\(secret)&period=0"
    let result = try BackupImporter.parse(Data(text.utf8))
    XCTAssertEqual(result.accounts.count, 1)
    XCTAssertEqual(result.issues.count, 2)
    XCTAssertEqual(result.issues.map(\.position), [2, 3])
  }

  func testUnknownAlgorithmsAndTypesRejected() throws {
    let result = try BackupImporter.parse(
      json([
        "a": ["secret": secret, "algorithm": "GOST3411_2012_256"],
        "b": ["secret": secret, "type": "unknown"],
        "c": ["secret": secret, "type": 99],
      ]))
    XCTAssertTrue(result.accounts.isEmpty)
    XCTAssertEqual(result.issues.count, 3)
  }

  func testHOTPRequiresValidCounterAndRejectsRepeatedParameters() throws {
    XCTAssertThrowsError(try BackupImporter.parseURI("otpauth://hotp/Test?secret=\(secret)"))
    XCTAssertThrowsError(
      try BackupImporter.parseURI("otpauth://hotp/Test?secret=\(secret)&counter=-1"))
    XCTAssertThrowsError(
      try BackupImporter.parseURI("otpauth://totp/Test?secret=\(secret)&period=30&period=60"))
    let account = try BackupImporter.parseURI("otpauth://hotp/Test?secret=\(secret)&counter=9")
    XCTAssertEqual(account.kind, .hotp)
    XCTAssertEqual(account.code(), "520489")
  }

  func testHexSteamBattleAndNumericEnums() throws {
    let result = try BackupImporter.parse(
      json([
        ["secret": "3132333435363738393031323334353637383930", "type": "hex"],
        ["secret": secret, "type": "steam"], ["secret": secret, "type": "battle"],
        ["secret": secret, "type": 1, "algorithm": 2],
      ]))
    XCTAssertEqual(result.accounts.count, 4)
    XCTAssertTrue(result.issues.isEmpty)
    XCTAssertEqual(result.accounts[0].code(at: Date(timeIntervalSince1970: 59)), "287082")
    XCTAssertEqual(result.accounts[1].code(at: Date(timeIntervalSince1970: 59)).count, 5)
    XCTAssertEqual(result.accounts[2].code(at: Date(timeIntervalSince1970: 59)), "94287082")
    XCTAssertEqual(result.accounts[3].algorithm, .sha256)
  }

  func testEmptyMalformedAndOversizedBackups() throws {
    XCTAssertThrowsError(try BackupImporter.parse(Data()))
    XCTAssertThrowsError(try BackupImporter.parse(Data("{broken}".utf8)))
    XCTAssertThrowsError(try BackupImporter.parse(Data("{}".utf8)))
    XCTAssertThrowsError(
      try BackupImporter.parse(Data(repeating: 65, count: BackupImporter.maximumBytes + 1)))
  }

  func testFractionalNumericParametersRejected() throws {
    let result = try BackupImporter.parse(
      json([["secret": secret, "period": 30.5], ["secret": secret, "digits": true]]))
    XCTAssertTrue(result.accounts.isEmpty)
    XCTAssertEqual(result.issues.count, 2)
  }

  func testBooleanTypeAlgorithmAndCounterRejected() throws {
    let result = try BackupImporter.parse(
      json([
        ["secret": secret, "type": true], ["secret": secret, "algorithm": false],
        ["secret": secret, "counter": true],
      ]))
    XCTAssertTrue(result.accounts.isEmpty)
    XCTAssertEqual(result.issues.count, 3)
  }

  func testArrayImportPreservesOrderBeyondTenEntries() throws {
    let result = try BackupImporter.parse(
      json((0..<12).map { ["secret": secret, "issuer": String($0)] }))
    XCTAssertEqual(result.accounts.map(\.issuer), (0..<12).map(String.init))
  }
}
