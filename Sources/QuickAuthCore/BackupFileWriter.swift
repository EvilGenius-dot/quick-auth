import Darwin
import Foundation

public enum BackupFileWriter {
  public static func write(_ data: Data, to destination: URL) throws {
    let temporary = destination.deletingLastPathComponent().appendingPathComponent(
      ".quick-auth-\(UUID().uuidString).tmp")
    let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
    guard descriptor >= 0 else { throw AuthError.invalid("无法在所选文件夹创建备份。") }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer {
      try? handle.close()
      try? FileManager.default.removeItem(at: temporary)
    }
    try handle.write(contentsOf: data)
    try handle.synchronize()
    try handle.close()
    guard rename(temporary.path, destination.path) == 0 else {
      throw AuthError.invalid("无法保存备份文件，原文件未被修改。")
    }
  }
}
