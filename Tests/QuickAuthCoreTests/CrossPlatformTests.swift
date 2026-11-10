import Foundation
import XCTest
@testable import QuickAuthCore

final class CrossPlatformTests: XCTestCase {
  func testWindowsAndMacEncryptedBackups() throws {
    guard let directory = ProcessInfo.processInfo.environment["QUICKAUTH_INTEROP_DIR"] else {
      throw XCTSkip("Run scripts/test-interop.sh for the Windows ↔ macOS backup test.")
    }
    let root = URL(fileURLWithPath: directory)
    let incoming = try BackupImporter.parse(Data(contentsOf: root.appendingPathComponent("windows.json")), password: "public-interop-密码")
    XCTAssertEqual(incoming.accounts.count, 2)
    XCTAssertEqual(incoming.accounts[0].issuer, "Cross-platform 测试")
    XCTAssertTrue(incoming.accounts[0].favorite)
    XCTAssertEqual(incoming.accounts[1].counter, UInt64.max)
    let data = try BackupExporter.encrypted(incoming.accounts, password: "public-interop-密码")
    try data.write(to: root.appendingPathComponent("macos.json"))
  }
}
