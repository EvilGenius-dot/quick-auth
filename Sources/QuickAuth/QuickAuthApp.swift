import AppKit
import ServiceManagement
import SwiftUI

@main
struct QuickAuthApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
  private var statusItem: NSStatusItem!
  private let popover = NSPopover()
  private var importWindow: NSWindow?
  private var exportWindow: NSWindow?
  private var store: AppStore!
  private var observers: [NSObjectProtocol] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    store = AppStore(demo: CommandLine.arguments.contains("--demo"))
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "lock.shield", accessibilityDescription: "Quick Auth 身份验证器")
      button.image?.isTemplate = true
      button.toolTip = "Quick Auth · 身份验证器"
      button.target = self
      button.action = #selector(togglePopover)
    }
    popover.contentSize = NSSize(width: 388, height: 568)
    popover.behavior = .transient
    popover.delegate = self
    popover.contentViewController = NSHostingController(
      rootView: MenuBarView(
        store: store,
        importAction: { [weak self] in self?.showImport() },
        exportAction: { [weak self] in self?.showExport() },
        loginAction: { [weak self] in self?.toggleLogin() }))
    let center = NSWorkspace.shared.notificationCenter
    for name in [
      NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
      NSWorkspace.sessionDidResignActiveNotification,
    ] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          Task { @MainActor in self?.store.lock() }
        })
    }
    DistributedNotificationCenter.default().addObserver(
      self, selector: #selector(screenLocked),
      name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
    observers.append(
      NotificationCenter.default.addObserver(forName: .vaultLocked, object: nil, queue: .main) {
        [weak self] _ in
        Task { @MainActor in
          self?.importWindow?.close()
          self?.importWindow = nil
          self?.exportWindow?.close()
          self?.exportWindow = nil
        }
      })
    if store.accounts.isEmpty || store.demo {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.togglePopover() }
    }
  }

  @objc private func screenLocked() { store.lock() }

  @objc private func togglePopover() {
    guard let button = statusItem.button else { return }
    if popover.isShown {
      popover.performClose(nil)
    } else {
      NSApp.activate(ignoringOtherApps: true)
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      popover.contentViewController?.view.window?.makeKey()
      NotificationCenter.default.post(name: .focusSearch, object: nil)
    }
  }

  private func showImport() {
    guard !store.isLocked, !store.loadFailed else { return }
    popover.performClose(nil)
    if let window = importWindow, window.isVisible {
      window.makeKeyAndOrderFront(nil)
      return
    }
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "添加账户 · Quick Auth"
    window.delegate = self
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(
      rootView: ImportView(store: store) { [weak self, weak window] in
        window?.close()
        self?.importWindow = nil
        self?.togglePopover()
      })
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    importWindow = window
  }

  private func showExport() {
    guard !store.isLocked, !store.loadFailed, !store.accounts.isEmpty else { return }
    popover.performClose(nil)
    if let window = exportWindow, window.isVisible {
      window.makeKeyAndOrderFront(nil)
      return
    }
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 550, height: 520),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "导出备份 · Quick Auth"
    window.delegate = self
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(
      rootView: ExportView(store: store) { [weak self, weak window] in
        window?.close()
        self?.exportWindow = nil
        self?.togglePopover()
      })
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    exportWindow = window
  }

  func windowWillClose(_ notification: Notification) {
    guard let window = notification.object as? NSWindow,
      window === importWindow || window === exportWindow
    else { return }
    // Release import text/password state even when the user closes with the titlebar.
    window.contentView = nil
    if window === importWindow { importWindow = nil }
    if window === exportWindow { exportWindow = nil }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    if importWindow?.isVisible != true && exportWindow?.isVisible != true && !popover.isShown {
      togglePopover()
    }
    return true
  }

  private func toggleLogin() {
    do {
      let service = SMAppService.mainApp
      if service.status == .enabled {
        try service.unregister()
        store.message = "已关闭登录时启动"
      } else {
        try service.register()
        if service.status == .requiresApproval {
          SMAppService.openSystemSettingsLoginItems()
          store.message = "请在系统设置中允许登录项"
        } else {
          store.message = "已开启登录时启动"
        }
      }
    } catch { store.error = "无法设置登录项。请先把应用放入「应用程序」文件夹，再重试。" }
  }

  func applicationWillTerminate(_ notification: Notification) { store.clearClipboard() }
}
