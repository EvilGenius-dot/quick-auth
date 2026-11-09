import XCTest

@testable import QuickAuthCore

final class OTPTests: XCTestCase {
  func testRFC6238AllAlgorithmsAndTimestamps() throws {
    let times: [TimeInterval] = [
      59, 1_111_111_109, 1_111_111_111, 1_234_567_890, 2_000_000_000, 20_000_000_000,
    ]
    let vectors: [(OTPAlgorithm, String, [String])] = [
      (
        .sha1, "12345678901234567890",
        ["94287082", "07081804", "14050471", "89005924", "69279037", "65353130"]
      ),
      (
        .sha256, "12345678901234567890123456789012",
        ["46119246", "68084774", "67062674", "91819424", "90698825", "77737706"]
      ),
      (
        .sha512, "1234567890123456789012345678901234567890123456789012345678901234",
        ["90693936", "25091201", "99943326", "93441116", "38618901", "47863826"]
      ),
    ]
    for (algorithm, key, expected) in vectors {
      let account = try OTPAccount(
        issuer: "RFC", account: "", secret: Data(key.utf8), algorithm: algorithm, digits: 8)
      for (time, code) in zip(times, expected) {
        XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: time)), code)
      }
    }
  }

  func testRFC4226HOTP() throws {
    let expected = [
      "755224", "287082", "359152", "969429", "338314", "254676", "287922", "162583", "399871",
      "520489",
    ]
    for (counter, code) in expected.enumerated() {
      let account = try OTPAccount(
        issuer: "RFC", account: "", secret: Data("12345678901234567890".utf8), kind: .hotp,
        counter: UInt64(counter))
      XCTAssertEqual(account.code(), code)
    }
  }

  func testTimeBoundaryUsesFloorAndCustomPeriod() throws {
    let account = try OTPAccount(
      issuer: "", account: "", secret: Data("12345678901234567890".utf8), period: 60)
    XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: 59.99)), "755224")
    XCTAssertEqual(account.code(at: Date(timeIntervalSince1970: 60)), "287082")
    XCTAssertEqual(account.remaining(at: Date(timeIntervalSince1970: 59.99)), 1)
    XCTAssertEqual(account.remaining(at: Date(timeIntervalSince1970: 60)), 60)
  }

  func testBase32RFC4648() throws {
    for (encoded, decoded) in [
      ("MY======", "f"), ("MZXQ====", "fo"), ("MZXW6===", "foo"), ("MZXW6YQ=", "foob"),
      ("MZXW6YTB", "fooba"), ("MZXW6YTBOI======", "foobar"),
    ] {
      XCTAssertEqual(try Base32.decode(encoded), Data(decoded.utf8))
      XCTAssertEqual(
        try Base32.decode(encoded.replacingOccurrences(of: "=", with: "").lowercased()),
        Data(decoded.utf8))
    }
  }

  func testInvalidBase32Fails() {
    for text in ["", "A", "ABC", "M1", "MZ", "M=Y=====", "MY=====", "MY======A", "😀"] {
      XCTAssertThrowsError(try Base32.decode(text), text)
    }
  }

  func testMergeIsIdempotentAndDoesNotRewindHOTP() throws {
    let current = try OTPAccount(
      issuer: "Current", account: "", secret: Data([1, 2, 3]), kind: .hotp, counter: 99)
    var backup = current
    backup.id = UUID()
    backup.counter = 0
    backup.issuer = "Old"
    let merged = ImportMerge(existing: [current], incoming: [backup, backup])
    XCTAssertEqual(merged.added, 0)
    XCTAssertEqual(merged.duplicates, 2)
    XCTAssertEqual(merged.accounts[0].counter, 99)
    XCTAssertEqual(merged.accounts[0].issuer, "Current")
  }

  func testSearchAcrossIssuerAndAccount() throws {
    let account = try OTPAccount(
      issuer: "GitHub 工作", account: "Test@example.com", secret: Data([1]))
    XCTAssertTrue(account.matches("github TEST"))
    XCTAssertTrue(account.matches("工作"))
    XCTAssertTrue(account.matches("  "))
    XCTAssertFalse(account.matches("Google"))
  }

  func testInvalidParametersCannotCreateAccount() throws {
    XCTAssertThrowsError(try OTPAccount(issuer: "", account: "", secret: Data()))
    XCTAssertThrowsError(try OTPAccount(issuer: "", account: "", secret: Data([1]), digits: 5))
    XCTAssertThrowsError(try OTPAccount(issuer: "", account: "", secret: Data([1]), period: 0))
  }
}
