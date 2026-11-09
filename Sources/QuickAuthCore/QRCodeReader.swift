import Foundation
import ImageIO
import Vision

public enum QRCodeReader {
  public static let maximumImageBytes = 20 * 1024 * 1024

  public static func read(_ data: Data) throws -> ImportPreview {
    guard data.count <= maximumImageBytes else { throw AuthError.invalid("二维码图片不能超过 20 MB。") }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw AuthError.invalid("无法读取图片，请选择 PNG、JPEG、HEIC 或 TIFF 图片。")
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: 4096, kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw AuthError.invalid("无法解码二维码图片。")
    }
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    try VNImageRequestHandler(cgImage: image).perform([request])
    let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
    return try parsePayloads(payloads)
  }

  public static func parsePayloads(_ payloads: [String]) throws -> ImportPreview {
    guard !payloads.isEmpty else { throw AuthError.invalid("未识别到二维码，请使用清晰、完整的二维码图片。") }
    var accounts: [OTPAccount] = []
    var issues: [ImportIssue] = []
    var seen = Set<String>()
    for (index, payload) in payloads.enumerated() where seen.insert(payload).inserted {
      do {
        accounts.append(
          try BackupImporter.parseURI(payload.trimmingCharacters(in: .whitespacesAndNewlines)))
      } catch {
        issues.append(.init(position: index + 1, reason: "二维码不是受支持的二步验证账户（需要 otpauth 格式）。"))
      }
    }
    return ImportPreview(accounts: accounts, issues: issues)
  }
}
