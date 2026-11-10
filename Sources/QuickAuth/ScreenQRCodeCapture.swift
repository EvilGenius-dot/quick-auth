import AppKit
import CoreGraphics
import QuickAuthCore

/// Uses macOS's own region-selection UI. Captures only the rectangle selected by
/// the user, into a private temporary directory removed after completion/cancel.
final class ScreenQRCodeCapture: ObservableObject {
  @Published private(set) var isCapturing = false
  @Published private(set) var error: String?
  private var process: Process?
  private var directory: URL?
  private var generation = UUID()
  private var quitObserver: NSObjectProtocol?

  init() {
    quitObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.cancel() }
  }

  deinit {
    if let quitObserver { NotificationCenter.default.removeObserver(quitObserver) }
    if process?.isRunning == true { process?.terminate() }
    if let directory { try? FileManager.default.removeItem(at: directory) }
  }

  func capture(window: NSWindow?, completion: @escaping (Data) -> Void) {
    guard !isCapturing else { return }
    error = nil
    guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
      error = L10n.text("请在系统设置 → 隐私与安全性 → 屏幕录制中允许 Quick Auth，然后重新打开应用。也可直接粘贴二维码截图。")
      return
    }
    let token = UUID()
    generation = token
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "quickauth-scan-\(token.uuidString)")
    do {
      try FileManager.default.createDirectory(
        at: folder, withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700])
    } catch {
      self.error = L10n.text("无法创建临时截图，请使用粘贴截图。")
      return
    }
    let file = folder.appendingPathComponent("selection.png")
    directory = folder
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-i", "-s", "-x", "-t", "png", file.path]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    task.terminationHandler = { [weak self, weak window] finished in
      DispatchQueue.main.async {
        defer { try? FileManager.default.removeItem(at: folder) }
        guard let self, self.generation == token else { return }
        self.process = nil
        self.directory = nil
        self.isCapturing = false
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Escape cancels macOS region selection without producing a file.
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        guard finished.terminationStatus == 0 else {
          self.error = L10n.text("屏幕截取未完成，请重试。")
          return
        }
        do {
          let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size <= QRCodeReader.maximumImageBytes else {
            throw AuthError.invalid(L10n.text("选区过大，请仅框选二维码区域。"))
          }
          let data = try Data(contentsOf: file)
          try? FileManager.default.removeItem(at: folder)
          completion(data)
        } catch { self.error = error.localizedDescription }
      }
    }
    process = task
    isCapturing = true
    NSApp.hide(nil)
    // Let the import window disappear before the system starts selecting a region.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak window] in
      guard let self, self.generation == token else { return }
      do { try task.run() } catch {
        self.cancel()
        self.error = L10n.text("无法启动系统截图工具，请使用粘贴截图。")
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
      }
    }
  }

  func cancel() {
    generation = UUID()
    isCapturing = false
    if process?.isRunning == true { process?.terminate() }
    process = nil
    if let directory { try? FileManager.default.removeItem(at: directory) }
    directory = nil
  }
}
