import CArgon2
import CommonCrypto
import CryptoKit
import Foundation

// Compatibility only: the extension's CryptoJS backups use the OpenSSL salted
// AES-256-CBC format and EVP_BytesToKey (MD5). New secrets are stored in Keychain.
enum BackupCrypto {
  static func decrypt(_ encoded: String, password: String) throws -> Data {
    guard let payload = Data(base64Encoded: encoded), payload.count >= 32,
      payload.prefix(8) == Data("Salted__".utf8), (payload.count - 16) % 16 == 0
    else {
      throw AuthError.decryptionFailed
    }
    let salt = payload[8..<16]
    let passwordData = Data(password.utf8)
    var material = Data()
    var previous = Data()
    while material.count < 48 {
      previous = Data(Insecure.MD5.hash(data: previous + passwordData + salt))
      material.append(previous)
    }
    let key = Data(material.prefix(32))
    let iv = Data(material.suffix(16))
    let ciphertext = Data(payload.dropFirst(16))
    var plaintext = Data(count: ciphertext.count + kCCBlockSizeAES128)
    var length = 0
    let capacity = plaintext.count
    let status = plaintext.withUnsafeMutableBytes { output in
      ciphertext.withUnsafeBytes { input in
        key.withUnsafeBytes { keyBytes in
          iv.withUnsafeBytes { ivBytes in
            CCCrypt(
              CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
              CCOptions(kCCOptionPKCS7Padding), keyBytes.baseAddress, key.count,
              ivBytes.baseAddress, input.baseAddress, ciphertext.count,
              output.baseAddress, capacity, &length)
          }
        }
      }
    }
    guard status == kCCSuccess, length > 0 else { throw AuthError.decryptionFailed }
    plaintext.count = length
    return plaintext
  }

  static func unlockKey(_ key: [String: Any], password: String) throws -> String {
    guard let salt = key["salt"] as? String, (8...1024).contains(salt.utf8.count),
      let encodedHash = key["hash"] as? String
    else { throw AuthError.decryptionFailed }
    // Bound untrusted verifier parameters before passing them into the C library.
    let fields = encodedHash.split(separator: "$", omittingEmptySubsequences: false)
    guard fields.count == 6, fields[1] == "argon2id", fields[2] == "v=19",
      encodedHash.utf8.count <= 512, !encodedHash.contains("\0")
    else { throw AuthError.decryptionFailed }
    let parameters = fields[3].split(separator: ",")
    guard parameters.count == 3 else { throw AuthError.decryptionFailed }
    var limits: [String: Int] = [:]
    for part in parameters {
      let pair = part.split(separator: "=")
      guard pair.count == 2, let value = Int(pair[1]), limits[String(pair[0])] == nil else {
        throw AuthError.decryptionFailed
      }
      limits[String(pair[0])] = value
    }
    guard let memory = limits["m"], (8...65536).contains(memory),
      let iterations = limits["t"], (1...10).contains(iterations),
      let parallelism = limits["p"], (1...4).contains(parallelism)
    else { throw AuthError.decryptionFailed }
    let passwordData = Data(password.utf8)
    let saltData = Data(salt.utf8)
    var hash = Data(count: 32)
    let status = hash.withUnsafeMutableBytes { output in
      passwordData.withUnsafeBytes { passwordBytes in
        saltData.withUnsafeBytes { saltBytes in
          argon2id_hash_raw(
            2, 19456, 1, passwordBytes.baseAddress, passwordData.count,
            saltBytes.baseAddress, saltData.count, output.baseAddress, 32)
        }
      }
    }
    guard status == 0 else { throw AuthError.decryptionFailed }
    let passphrase = hash.base64EncodedString().replacingOccurrences(of: "=", with: "")
    let value = Data(passphrase.utf8)
    let verified = value.withUnsafeBytes { bytes in
      encodedHash.withCString { argon2id_verify($0, bytes.baseAddress, value.count) }
    }
    guard verified == 0 else { throw AuthError.decryptionFailed }
    return passphrase
  }
}
