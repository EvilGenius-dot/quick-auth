import QuickAuthCore
import ServiceManagement
import SwiftUI

extension Color {
  static let authAccent = Color(red: 0.05, green: 0.52, blue: 0.46)
  static let authCanvas = Color(nsColor: .windowBackgroundColor)
}

struct MenuBarView: View {
  @ObservedObject var store: AppStore
  let importAction: () -> Void
  let exportAction: () -> Void
  let loginAction: () -> Void
  @FocusState private var searchFocused: Bool
  @State private var deleting: OTPAccount?
  @State private var advancing: OTPAccount?

  var body: some View {
    VStack(spacing: 0) {
      header
      if store.isLocked {
        lockedState
      } else if store.loadFailed {
        loadError
      } else {
        searchBar.padding(.horizontal, 20).padding(.bottom, 14)
        if store.accounts.isEmpty { emptyState } else { accountList }
      }
      if let message = store.message {
        HStack(spacing: 7) {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.authAccent)
          Text(message).font(.system(size: 11)).lineLimit(2)
          Spacer(minLength: 0)
          Button {
            store.message = nil
          } label: {
            Image(systemName: "xmark").font(.system(size: 9))
          }.buttonStyle(.plain)
        }.padding(10).background(Color.authAccent.opacity(0.08))
      }
      footer
    }
    .frame(width: 388, height: 568)
    .background(Color.authCanvas)
    .tint(.authAccent)
    .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in searchFocused = true
    }
    .alert(
      "操作未完成",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("好", role: .cancel) { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .alert(
      "移除这个账户？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("取消", role: .cancel) { deleting = nil }
      Button("移除", role: .destructive) {
        if let account = deleting { store.delete(account) }
        deleting = nil
      }
    } message: {
      Text("将从 Quick Auth 移除「\(deleting?.title ?? "")」。请确认你仍保留原插件或备份。")
    }
    .alert(
      "生成下一个 HOTP 验证码？",
      isPresented: Binding(get: { advancing != nil }, set: { if !$0 { advancing = nil } })
    ) {
      Button("取消", role: .cancel) { advancing = nil }
      Button("下一个") {
        if let account = advancing { store.advance(account) }
        advancing = nil
      }
    } message: {
      Text("计数器会增加 1。仅在当前验证码已使用后继续，避免与服务端失去同步。")
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "lock.shield.fill").font(.system(size: 20, weight: .medium))
        .foregroundStyle(.white).frame(width: 38, height: 38)
        .background(
          LinearGradient(
            colors: [.authAccent, Color(red: 0.08, green: 0.38, blue: 0.37)],
            startPoint: .topLeading, endPoint: .bottomTrailing),
          in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 2) {
        Text("Quick Auth").font(.system(size: 17, weight: .semibold))
        Text("验证码，随手可得").font(.system(size: 10)).foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 4) {
        Circle().fill(store.demo ? Color.orange : Color.authAccent).frame(width: 5, height: 5)
        Text(store.demo ? "演示模式" : "仅本机").font(.system(size: 10, weight: .medium))
      }.foregroundStyle(.secondary).padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }.padding(20).padding(.bottom, 2)
  }

  private var searchBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.secondary)
      TextField("搜索账户或服务…", text: $store.query).textFieldStyle(.plain)
        .font(.system(size: 13)).focused($searchFocused)
        .onSubmit { if let account = store.visibleAccounts.first { store.copy(account) } }
      if !store.query.isEmpty {
        Button {
          store.query = ""
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
        }.buttonStyle(.plain)
          .help("清除搜索")
      } else {
        Text("↵ 复制").font(.system(size: 10)).foregroundStyle(.tertiary)
      }
    }.padding(.horizontal, 12).padding(.vertical, 11)
      .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06)))
      .onExitCommand { store.query = "" }
  }

  private var accountList: some View {
    VStack(spacing: 0) {
      HStack(spacing: 4) {
        filter("全部账户", favorite: false)
        filter("已收藏", favorite: true)
        Spacer()
        Text("\(store.visibleAccounts.count) 个").font(.system(size: 10)).foregroundStyle(.tertiary)
      }.padding(.horizontal, 20).padding(.bottom, 10)
      if store.visibleAccounts.isEmpty {
        Spacer()
        Image(systemName: "magnifyingglass").font(.system(size: 26)).foregroundStyle(.tertiary)
        Text("没有找到匹配的账户").font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 10)
        Button("查看全部账户") {
          store.query = ""
          store.favoritesOnly = false
        }.buttonStyle(.plain).foregroundStyle(Color.authAccent).padding(.top, 8)
        Spacer()
      } else {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          ScrollView {
            LazyVStack(spacing: 9) {
              ForEach(store.visibleAccounts) { account in
                AccountCard(
                  account: account, date: context.date, copied: store.copiedID == account.id,
                  copy: { store.copy(account) }, favorite: { store.toggleFavorite(account) }
                )
                .contextMenu {
                  Button("复制验证码") { store.copy(account) }
                  Button(account.favorite ? "取消收藏" : "收藏账户") { store.toggleFavorite(account) }
                  if account.kind == .hotp { Button("下一个 HOTP 验证码…") { advancing = account } }
                  Divider()
                  Button("移除账户…", role: .destructive) { deleting = account }
                }
              }
            }.padding(.horizontal, 20).padding(.bottom, 16)
          }
        }
      }
    }.frame(maxHeight: .infinity)
  }

  private func filter(_ title: String, favorite: Bool) -> some View {
    Button {
      store.favoritesOnly = favorite
    } label: {
      Text(title).font(
        .system(size: 11, weight: store.favoritesOnly == favorite ? .semibold : .regular)
      )
      .padding(.horizontal, 9).padding(.vertical, 5)
      .foregroundStyle(store.favoritesOnly == favorite ? Color.authAccent : .secondary)
      .background(
        store.favoritesOnly == favorite ? Color.authAccent.opacity(0.09) : .clear,
        in: RoundedRectangle(cornerRadius: 6))
    }.buttonStyle(.plain)
  }

  private var emptyState: some View {
    VStack(spacing: 0) {
      Spacer()
      ZStack {
        Circle().fill(Color.authAccent.opacity(0.06)).frame(width: 98, height: 98)
        Circle().fill(Color.authAccent.opacity(0.08)).frame(width: 70, height: 70)
        Image(systemName: "key.horizontal").font(.system(size: 29, weight: .light)).foregroundStyle(
          Color.authAccent)
      }
      Text("把验证码带到菜单栏").font(.system(size: 19, weight: .semibold)).padding(.top, 20)
      Text("导入 Chrome 身份验证器的备份，\n下次登录，点一下就好。").font(.system(size: 12)).foregroundStyle(.secondary)
        .multilineTextAlignment(.center).lineSpacing(5).padding(.top, 9)
      Button(action: importAction) {
        Label("导入我的账户", systemImage: "square.and.arrow.down").padding(.horizontal, 15).padding(
          .vertical, 5)
      }
      .buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 24)
      Text("支持 JSON / TXT · 密码保护备份").font(.system(size: 10)).foregroundStyle(.tertiary).padding(
        .top, 12)
      Spacer()
      Spacer().frame(height: 20)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var lockedState: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: "lock.shield").font(.system(size: 44, weight: .light)).foregroundStyle(
        Color.authAccent)
      Text("验证码已锁定").font(.system(size: 19, weight: .semibold))
      Text("使用 Touch ID 或 Mac 登录密码继续").font(.system(size: 12)).foregroundStyle(.secondary)
      Button(store.isUnlocking ? "正在验证…" : "解锁") { store.unlock() }.buttonStyle(.borderedProminent)
        .controlSize(.large).disabled(store.isUnlocking)
      Spacer()
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var loadError: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: "exclamationmark.lock").font(.system(size: 36)).foregroundStyle(.orange)
      Text("暂时无法读取账户").font(.headline)
      Text("请检查钥匙串权限，然后重试。\n现有账户不会被覆盖。").multilineTextAlignment(.center).foregroundStyle(.secondary)
      Button("重新读取") { store.reload() }.buttonStyle(.borderedProminent)
      Spacer()
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Button(action: importAction) {
        Label("添加账户", systemImage: "plus").font(.system(size: 12, weight: .medium))
      }
      .buttonStyle(.plain).foregroundStyle(Color.authAccent).disabled(
        store.isLocked || store.loadFailed)
      Spacer()
      Text("本地生成 · 离线可用").font(.system(size: 9)).foregroundStyle(.tertiary)
      Menu {
        Button("添加账户 / 导入…", action: importAction).disabled(store.isLocked || store.loadFailed)
        Button("导出备份…", action: exportAction).disabled(
          store.isLocked || store.loadFailed || store.accounts.isEmpty)
        Button("锁定验证码") { store.lock() }.disabled(store.isLocked || store.demo)
        Divider()
        Button(SMAppService.mainApp.status == .enabled ? "关闭登录时启动" : "登录时启动", action: loginAction)
          .disabled(store.demo)
        Divider()
        Button("退出 Quick Auth") { NSApp.terminate(nil) }.keyboardShortcut("q")
      } label: {
        Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(.secondary)
      }
      .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("设置")
    }.padding(.horizontal, 20).padding(.vertical, 14)
      .background(Color.primary.opacity(0.025))
      .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1) }
  }
}

private struct AccountCard: View {
  let account: OTPAccount
  let date: Date
  let copied: Bool
  let copy: () -> Void
  let favorite: () -> Void
  @State private var hovering = false
  private var remaining: Int { account.remaining(at: date) }
  private var color: Color {
    let palette: [Color] = [.authAccent, .indigo, .orange, .blue, .purple]
    return palette[account.title.utf8.reduce(0) { ($0 + Int($1)) % palette.count }]
  }
  private var formattedCode: String {
    let code = account.code(at: date)
    if account.kind == .steam { return code }
    let middle = code.index(code.startIndex, offsetBy: code.count / 2)
    return String(code[..<middle]) + " " + String(code[middle...])
  }

  var body: some View {
    VStack(spacing: 13) {
      HStack(spacing: 9) {
        Text(String(account.title.prefix(1)).uppercased()).font(
          .system(size: 14, weight: .semibold)
        )
        .foregroundStyle(color).frame(width: 32, height: 32)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 3) {
          Text(account.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
          Text(account.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer(minLength: 0)
        Button(action: favorite) {
          Image(systemName: account.favorite ? "star.fill" : "star").font(.system(size: 11))
            .foregroundStyle(
              account.favorite
                ? Color.orange.opacity(0.85) : Color.secondary.opacity(hovering ? 0.6 : 0.25))
        }.buttonStyle(.plain).help(account.favorite ? "取消收藏" : "收藏")
      }
      HStack {
        Button(action: copy) {
          HStack(spacing: 9) {
            Text(formattedCode).font(
              .system(size: account.digits > 8 ? 23 : 27, weight: .medium, design: .monospaced)
            ).tracking(1.4)
            Image(systemName: copied ? "checkmark" : "square.on.square").font(.system(size: 12))
              .opacity(copied || hovering ? 1 : 0.3)
          }.foregroundStyle(copied ? Color.authAccent : Color.primary)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).help(copied ? "已复制 · 30 秒后自动清除" : "复制验证码")
          .accessibilityLabel("复制 \(account.title) 的验证码")
        Spacer(minLength: 4)
        if account.kind == .hotp {
          Text("HOTP").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        } else {
          ZStack {
            Circle().stroke(Color.primary.opacity(0.06), lineWidth: 2)
            Circle().trim(from: 0, to: Double(remaining) / Double(account.period))
              .stroke(
                remaining <= 5 ? Color.orange : Color.authAccent.opacity(0.7),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
              ).rotationEffect(.degrees(-90))
            Text("\(remaining)").font(.system(size: 9, weight: .medium, design: .monospaced))
              .foregroundStyle(.secondary)
          }.frame(width: 27, height: 27).help("\(remaining) 秒后刷新")
        }
      }
    }.padding(14)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).strokeBorder(
          copied ? Color.authAccent.opacity(0.5) : Color.primary.opacity(hovering ? 0.12 : 0.055))
      )
      .onHover { hovering = $0 }
  }
}
