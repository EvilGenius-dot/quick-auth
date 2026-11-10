import QuickAuthCore
import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
  @ObservedObject var store: AppStore
  let finish: () -> Void
  @State private var encrypted = true
  @State private var password = ""
  @State private var confirmation = ""
  @State private var acceptedPlaintext = false
  @State private var busy = false
  @State private var error: String?
  @State private var generation = UUID()
  @State private var exportTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Label(L10n.text("导出备份"), systemImage: "square.and.arrow.up").font(.system(size: 23, weight: .semibold))
      Text(L10n.text("将全部 \(store.accounts.count) 个账户保存到你选择的位置。")).foregroundStyle(.secondary)
      Picker(L10n.text("备份格式"), selection: $encrypted) {
        Text(L10n.text("密码加密 · 推荐")).tag(true)
        Text(L10n.text("明文 · 兼容 Chrome 插件")).tag(false)
      }.pickerStyle(.radioGroup).disabled(busy)
      if encrypted {
        VStack(alignment: .leading, spacing: 10) {
          SecureField(L10n.text("备份密码（至少 8 个字符）"), text: $password)
          SecureField(L10n.text("再次输入备份密码"), text: $confirmation)
          Text(L10n.text("用于 Quick Auth 恢复。请保管好密码，忘记后无法解密备份。")).font(.system(size: 11)).foregroundStyle(
            .secondary)
        }.textFieldStyle(.roundedBorder).disabled(busy)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          Label(L10n.text("明文文件包含全部账户密钥"), systemImage: "exclamationmark.triangle.fill").foregroundStyle(
            .orange)
          Text(L10n.text("持有文件的人可以生成你的验证码。仅在迁移到其他验证器时使用，并保存在安全位置。")).font(.system(size: 12)).foregroundStyle(
            .secondary)
          Toggle(L10n.text("我了解明文备份包含密钥"), isOn: $acceptedPlaintext).toggleStyle(.checkbox)
        }.disabled(busy)
      }
      if let error { Text(error).font(.system(size: 12)).foregroundStyle(.red) }
      Spacer()
      Label(L10n.text("导出在本机完成，文件不会上传。"), systemImage: "lock.shield").font(.system(size: 11)).foregroundStyle(
        .secondary)
      Divider()
      HStack {
        Button(L10n.text("取消"), action: finish).keyboardShortcut(.cancelAction)
        Spacer()
        if busy { ProgressView().controlSize(.small) }
        Button(L10n.text("导出到文件…"), action: export).buttonStyle(.borderedProminent).keyboardShortcut(
          .defaultAction
        )
        .disabled(
          busy || store.accounts.isEmpty || store.isLocked || store.loadFailed
            || (encrypted ? password.count < 8 || password != confirmation : !acceptedPlaintext))
      }
    }.padding(28).frame(width: 550, height: 520).background(Color.authCanvas).tint(.authAccent)
      .onDisappear {
        generation = UUID()
        exportTask?.cancel()
        password = ""
        confirmation = ""
      }
  }

  private func export() {
    guard !store.isLocked, !store.loadFailed, !store.accounts.isEmpty else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.canCreateDirectories = true
    panel.directoryURL =
      FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    panel.nameFieldStringValue =
      "quick-auth-backup-\(formatter.string(from: Date()))\(encrypted ? "-encrypted" : "-plaintext").json"
    guard panel.runModal() == .OK, let url = panel.url, !store.isLocked else { return }
    let accounts = store.accounts
    let password = password
    let useEncryption = encrypted
    let token = UUID()
    generation = token
    busy = true
    error = nil
    exportTask = Task {
      let result = await Task.detached(priority: .userInitiated) {
        Result {
          try useEncryption
            ? BackupExporter.encrypted(accounts, password: password)
            : BackupExporter.plaintext(accounts)
        }
      }.value
      guard generation == token, !Task.isCancelled, !store.isLocked else { return }
      busy = false
      do {
        let data = try result.get()
        try BackupFileWriter.write(data, to: url)
        store.message = L10n.text("已导出 \(accounts.count) 个账户\(useEncryption ? L10n.text("（密码保护）") : L10n.text("（明文）"))")
        self.password = ""
        confirmation = ""
        finish()
      } catch { self.error = L10n.text("导出未完成：\(error.localizedDescription)") }
    }
  }
}
