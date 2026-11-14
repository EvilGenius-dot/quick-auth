import QuickAuthCore
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
  @ObservedObject var store: AppStore
  let finish: () -> Void
  @State private var source = 0
  @State private var manual = AccountInput()
  @StateObject private var screenCapture = ScreenQRCodeCapture()
  @State private var text = ""
  @State private var fileData: Data?
  @State private var fileName = ""
  @State private var password = ""
  @State private var needsPassword = false
  @State private var preview: ImportPreview?
  @State private var error: String?
  @State private var busy = false
  @State private var allowPartial = false
  @State private var generation = UUID()
  @State private var parseTask: Task<Void, Never>?

  private var merge: ImportMerge? {
    preview.map { ImportMerge(existing: store.accounts, incoming: $0.accounts) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 13) {
        Image(systemName: "square.and.arrow.down").font(.system(size: 27, weight: .light))
          .foregroundStyle(Color.authAccent)
          .frame(width: 54, height: 54).background(
            Color.authAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
        VStack(alignment: .leading, spacing: 5) {
          Text(L10n.text("添加你的验证账户")).font(.system(size: 22, weight: .semibold))
          Text(L10n.text("导入备份、填写密钥，或扫描二步验证二维码。")).font(.system(size: 12)).foregroundStyle(.secondary)
        }
      }
      Picker(L10n.text("导入来源"), selection: $source) {
        Text(L10n.text("备份文件")).tag(0)
        Text(L10n.text("粘贴链接")).tag(1)
        Text(L10n.text("手动输入")).tag(2)
        Text(L10n.text("二维码")).tag(3)
      }.pickerStyle(.segmented)
        .onChange(of: source) { _ in
          resetPreview()
          screenCapture.cancel()
        }

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if source == 0 {
            VStack(spacing: 12) {
              Image(systemName: fileData == nil ? "doc.badge.arrow.up" : "doc.text.fill").font(
                .system(size: 29, weight: .light)
              ).foregroundStyle(Color.authAccent)
              Text(fileData == nil ? L10n.text("选择 Quick Auth / Authenticator 备份") : fileName).font(
                .system(size: 13, weight: .medium)
              ).lineLimit(1)
              Text(L10n.text("支持 .json、.txt 和密码保护备份")).font(.system(size: 11)).foregroundStyle(.secondary)
              Button(fileData == nil ? L10n.text("选择文件…") : L10n.text("重新选择…"), action: chooseFile).controlSize(.large)
            }.frame(maxWidth: .infinity).padding(.vertical, 22)
              .background(Color.authAccent.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
              .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                  Color.authAccent.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
          } else if source == 1 {
            VStack(alignment: .leading, spacing: 7) {
              Text(L10n.text("每行一个 otpauth:// 链接，也可粘贴 JSON 备份。")).font(.system(size: 11)).foregroundStyle(
                .secondary)
              TextEditor(text: $text).font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8).frame(height: 140).background(
                  Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 9)
                )
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.1)))
                .onChange(of: text) { _ in resetPreview() }
            }
          }

          if source == 2 { manualForm }
          if source == 3 { qrForm }

          if needsPassword {
            VStack(alignment: .leading, spacing: 7) {
              Label(L10n.text("此备份受密码保护"), systemImage: "lock.fill").font(.system(size: 12, weight: .medium))
              SecureField(L10n.text("输入导出时设置的备份密码"), text: $password).textFieldStyle(.roundedBorder).onSubmit(
                parse)
              Text(L10n.text("密码仅用于本次本机解密，不会保存。")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
          }
          if let error {
            Label(error, systemImage: "exclamationmark.circle").font(.system(size: 12))
              .foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
          }

          if let preview, let merge {
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text(L10n.text("导入预览")).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L10n.text("新增 \(merge.added) · 重复 \(merge.duplicates)")).font(.system(size: 11))
                  .foregroundStyle(Color.authAccent)
              }
              LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(preview.accounts) { account in
                  HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.authAccent)
                    Text(account.title).fontWeight(.medium).lineLimit(1)
                    Text(account.subtitle).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(account.kind.rawValue.uppercased()).font(
                      .system(size: 9, design: .monospaced)
                    ).foregroundStyle(.tertiary)
                  }.font(.system(size: 11))
                }
                ForEach(preview.issues) { issue in
                  Label(
                    L10n.text("第 \(issue.position) 条：\(issue.reason)"), systemImage: "exclamationmark.triangle"
                  ).font(.system(size: 11)).foregroundStyle(.orange)
                }
              }.padding(1)
              if !preview.issues.isEmpty {
                Toggle(L10n.text("跳过 \(preview.issues.count) 条无法导入的记录，继续导入有效账户"), isOn: $allowPartial).font(
                  .system(size: 11)
                ).toggleStyle(.checkbox)
              }
            }.padding(14).background(
              Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
          } else if !needsPassword && source == 0 {
            VStack(alignment: .leading, spacing: 6) {
              Text(L10n.text("在 Chrome 插件中导出")).font(.system(size: 12, weight: .medium))
              Text(L10n.text("打开「身份验证器」→ 设置 → 备份 → 下载备份文件或下载密码保护备份。")).font(.system(size: 11)).foregroundStyle(
                .secondary
              ).lineSpacing(4)
            }.padding(.vertical, 5)
          }
        }.padding(2)
      }.frame(maxHeight: .infinity)
      HStack(spacing: 5) {
        Image(systemName: "lock.shield").foregroundStyle(Color.authAccent)
        Text(store.demo ? L10n.text("演示模式：本次导入不会保存") : L10n.text("密钥保存在 macOS 钥匙串 · 不上传任何数据")).foregroundStyle(.secondary)
      }.font(.system(size: 10))
      Divider()
      HStack {
        Button(L10n.text("取消"), action: finish).keyboardShortcut(.cancelAction)
        Spacer()
        if busy {
          ProgressView().controlSize(.small)
          Text(L10n.text("正在解析…")).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        if let preview, let merge {
          Button(merge.added == 0 ? L10n.text("完成（均已存在）") : L10n.text("导入 \(merge.added) 个账户")) { save(preview) }
            .buttonStyle(AuthPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            .disabled(
              busy || preview.accounts.isEmpty || (!preview.issues.isEmpty && !allowPartial))
        } else {
          Button(needsPassword ? L10n.text("解密并预览") : L10n.text("预览账户"), action: previewInput).buttonStyle(AuthPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            .disabled(
              busy || source == 3 || (source == 0 && fileData == nil)
                || (source == 1 && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                || (needsPassword && password.isEmpty))
        }
      }
    }.padding(26).frame(width: 600, height: 700).authGlassSurface()
      .onChange(of: manual) { _ in resetPreview() }
      .onDisappear {
        screenCapture.cancel()
        manual.secret = ""
        generation = UUID()
        parseTask?.cancel()
        password = ""
        fileData = nil
        text = ""
        preview = nil
      }
  }

  private var manualForm: some View {
    VStack(alignment: .leading, spacing: 13) {
      Text(L10n.text("输入网站或 App 在开启二步验证时提供的设置密钥。")).font(.system(size: 12)).foregroundStyle(.secondary)
      TextField(L10n.text("服务名称，例如 GitHub"), text: $manual.issuer)
      TextField(L10n.text("账号或邮箱"), text: $manual.account)
      SecureField(L10n.text("设置密钥（不是当前的六位验证码）"), text: $manual.secret)
      Picker(L10n.text("密钥编码"), selection: $manual.hexadecimal) {
        Text(L10n.text("Base32（常用）")).tag(false)
        Text(L10n.text("十六进制")).tag(true)
      }
      Picker(L10n.text("验证码类型"), selection: $manual.kind) {
        Text(L10n.text("基于时间 TOTP（常用）")).tag(OTPKind.totp)
        Text(L10n.text("基于计数 HOTP")).tag(OTPKind.hotp)
        Text("Steam").tag(OTPKind.steam)
      }
      HStack {
        Picker(L10n.text("算法"), selection: $manual.algorithm) {
          ForEach(OTPAlgorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        if manual.kind != .steam {
          Picker(L10n.text("位数"), selection: $manual.digits) {
            ForEach(6...10, id: \.self) { Text(L10n.text("\($0) 位")).tag($0) }
          }
        }
      }
      if manual.kind == .hotp {
        LabeledContent(L10n.text("初始计数器")) { TextField("0", text: $manual.counter) }
      } else {
        LabeledContent(L10n.text("刷新周期（秒）")) { TextField("30", text: $manual.period) }
      }
      Text(L10n.text("服务未指定参数时，使用 TOTP、SHA1、6 位、30 秒即可。")).font(.system(size: 11)).foregroundStyle(.secondary)
    }.textFieldStyle(.roundedBorder)
  }

  private var qrForm: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(L10n.text("扫描服务提供的二步验证二维码，识别后先预览再保存。")).font(.system(size: 12)).foregroundStyle(.secondary)
      HStack {
        Button(L10n.text("选择二维码图片…"), action: chooseQRCode)
        Button(L10n.text("粘贴截图"), action: pasteQRCode)
        Spacer()
        Button(screenCapture.isCapturing ? L10n.text("正在框选…") : L10n.text("屏幕扫码")) {
          resetPreview()
          screenCapture.capture(window: NSApp.keyWindow) { data in
            guard source == 3, !store.isLocked else { return }
            scanImage(data)
          }
        }.disabled(screenCapture.isCapturing)
      }.disabled(busy)
      if preview == nil {
        Image(systemName: "viewfinder").font(.system(size: 62, weight: .ultraLight))
          .foregroundStyle(Color.authAccent)
          .frame(maxWidth: .infinity).padding(.vertical, 24)
        Text(L10n.text("先在浏览器中显示二维码，再点击「屏幕扫码」并拖动框选二维码；按 Esc 取消。"))
          .font(.system(size: 12)).foregroundStyle(.secondary)
      }
      if let captureError = screenCapture.error {
        Text(captureError).font(.system(size: 12)).foregroundStyle(.orange)
      }
      Text(L10n.text("支持标准 otpauth 二维码；暂不支持 Google 验证器的批量迁移二维码。")).font(.system(size: 10)).foregroundStyle(
        .secondary)
    }
  }

  private func previewInput() {
    if source == 2 {
      do {
        let account = try manual.makeAccount()
        preview = ImportPreview(accounts: [account], issues: [])
        error = nil
      } catch { self.error = error.localizedDescription }
    } else {
      parse()
    }
  }

  private func chooseQRCode() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= QRCodeReader.maximumImageBytes else {
        throw AuthError.invalid(L10n.text("二维码图片不能超过 20 MB。"))
      }
      scanImage(try Data(contentsOf: url))
    } catch { self.error = error.localizedDescription }
  }

  private func pasteQRCode() {
    guard
      let data = NSPasteboard.general.data(forType: .png)
        ?? NSPasteboard.general.data(forType: .tiff)
    else {
      error = L10n.text("剪贴板中没有图片。可以按 Control + Shift + Command + 4 截取二维码后再粘贴。")
      return
    }
    scanImage(data)
  }

  private func scanImage(_ data: Data) {
    resetPreview()
    screenCapture.cancel()
    let token = UUID()
    generation = token
    busy = true
    parseTask = Task {
      let result = await Task.detached(priority: .userInitiated) {
        Result { try QRCodeReader.read(data) }
      }.value
      guard generation == token, !Task.isCancelled else { return }
      busy = false
      switch result {
      case .success(let value): preview = value
      case .failure(let failure): error = failure.localizedDescription
      }
    }
  }

  private func resetPreview() {
    generation = UUID()
    parseTask?.cancel()
    busy = false
    preview = nil
    error = nil
    needsPassword = false
    password = ""
    allowPartial = false
  }

  private func chooseFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json, .plainText]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = L10n.text("选择 Quick Auth 或 Chrome 身份验证器导出的备份")
    guard panel.runModal() == .OK, let url = panel.url else { return }
    resetPreview()
    fileData = nil
    fileName = ""
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= BackupImporter.maximumBytes else {
        throw AuthError.invalid(L10n.text("备份文件超过 5 MB，无法导入。"))
      }
      fileData = try Data(contentsOf: url)
      fileName = url.lastPathComponent
      parse()
    } catch { self.error = L10n.text("无法读取备份：\(error.localizedDescription)") }
  }

  private func parse() {
    guard !busy else { return }
    let data = source == 0 ? fileData : Data(text.utf8)
    guard let data else { return }
    let password = password
    let token = UUID()
    generation = token
    busy = true
    error = nil
    preview = nil
    parseTask = Task {
      let result = await Task.detached(priority: .userInitiated) {
        Result { try BackupImporter.parse(data, password: password.isEmpty ? nil : password) }
      }.value
      guard generation == token, !Task.isCancelled else { return }
      busy = false
      switch result {
      case .success(let value):
        preview = value
        self.password = ""
        needsPassword = false
      case .failure(let failure):
        if failure as? AuthError == .passwordRequired {
          needsPassword = true
        } else {
          error = failure.localizedDescription
        }
      }
    }
  }

  private func save(_ preview: ImportPreview) {
    do {
      _ = try store.merge(preview.accounts)
      password = ""
      fileData = nil
      text = ""
      finish()
    } catch { self.error = error.localizedDescription }
  }
}
