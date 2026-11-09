import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import QuickAuthCore

final class QRCodeTests: XCTestCase {
  let uri =
    "otpauth://totp/Fixture:test%40example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Fixture&digits=8"

  func testActualQRCodeImageRecognition() throws {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(uri.utf8)
    let qr = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    let padded = qr.composited(
      over: CIImage(color: .white).cropped(to: qr.extent.insetBy(dx: -32, dy: -32)))
    let image = try XCTUnwrap(
      CIContext(options: [.useSoftwareRenderer: true]).createCGImage(padded, from: padded.extent))
    let data = NSMutableData()
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let preview = try QRCodeReader.read(data as Data)
    XCTAssertEqual(preview.accounts.count, 1)
    XCTAssertTrue(preview.issues.isEmpty)
    XCTAssertEqual(preview.accounts.first?.account, "test@example.com")
    XCTAssertEqual(preview.accounts.first?.code(at: Date(timeIntervalSince1970: 59)), "94287082")
  }

  func testMultipleQRPayloadsDuplicatesAndInvalidCodes() throws {
    let preview = try QRCodeReader.parsePayloads([
      uri, uri, "https://example.com", "otpauth-migration://offline?data=abc",
    ])
    XCTAssertEqual(preview.accounts.count, 1)
    XCTAssertEqual(preview.issues.count, 2)
  }

  func testInvalidAndOversizedImagesRejected() {
    XCTAssertThrowsError(try QRCodeReader.read(Data("not-an-image".utf8)))
    XCTAssertThrowsError(
      try QRCodeReader.read(Data(repeating: 0, count: QRCodeReader.maximumImageBytes + 1)))
    XCTAssertThrowsError(try QRCodeReader.parsePayloads([]))
  }
}
