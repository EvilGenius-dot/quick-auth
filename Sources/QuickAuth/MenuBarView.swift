import QuickAuthCore
import ServiceManagement
import SwiftUI

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
    .frame(width: 400, height: 600)
    .authGlassSurface()
    .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in searchFocused = true
    }
    .alert(
      L10n.text("操作未完成"),
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button(L10n.text("好"), role: .cancel) { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .alert(
      L10n.text("移除这个账户？"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button(L10n.text("取消"), role: .cancel) { deleting = nil }
      Button(L10n.text("移除"), role: .destructive) {
        if let account = deleting { store.delete(account) }
        deleting = nil
      }
    } message: {
      Text(L10n.text("将从 Quick Auth 移除「\(deleting?.title ?? "")」。请确认你仍保留原插件或备份。"))
    }
    .alert(
      L10n.text("生成下一个 HOTP 验证码？"),
      isPresented: Binding(get: { advancing != nil }, set: { if !$0 { advancing = nil } })
    ) {
      Button(L10n.text("取消"), role: .cancel) { advancing = nil }
      Button(L10n.text("下一个")) {
        if let account = advancing { store.advance(account) }
        advancing = nil
      }
    } message: {
      Text(L10n.text("计数器会增加 1。仅在当前验证码已使用后继续，避免与服务端失去同步。"))
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "lock.shield").font(.system(size: 22, weight: .light))
        .foregroundStyle(Color.authText).frame(width: 42, height: 42)
        .background(
          LinearGradient(
            colors: [.authAccent.opacity(0.28), .authBlue.opacity(0.07)],
            startPoint: .topLeading, endPoint: .bottomTrailing),
          in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Color.authAccent.opacity(0.4)))
      VStack(alignment: .leading, spacing: 5) {
        Text("QUICK AUTH").font(.system(size: 15, weight: .semibold, design: .monospaced)).tracking(1.8)
        Text(L10n.text("验证码，随手可得")).font(.system(size: 10)).foregroundStyle(Color.authMuted)
      }
      Spacer()
      HStack(spacing: 4) {
        Circle().fill(Color.authBlue).frame(width: 4, height: 4)
          .shadow(color: .authBlue.opacity(0.55), radius: 4)
        Text(store.demo ? L10n.text("演示模式") : L10n.text("仅本机")).font(.system(size: 10, weight: .medium))
      }.foregroundStyle(Color.authMuted).padding(.horizontal, 8).padding(.vertical, 6)
        .overlay(Capsule().strokeBorder(Color.authLine))
    }.padding(22).padding(.bottom, 1)
  }

  private var searchBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.secondary)
      TextField(L10n.text("搜索账户或服务…"), text: $store.query).textFieldStyle(.plain)
        .font(.system(size: 13)).focused($searchFocused)
        .onSubmit { if let account = store.visibleAccounts.first { store.copy(account) } }
      if !store.query.isEmpty {
        Button {
          store.query = ""
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
        }.buttonStyle(.plain)
          .help(L10n.text("清除搜索"))
      } else {
        Text("↵").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.authMuted)
          .frame(width: 24, height: 22)
          .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.authLine))
      }
    }.padding(.horizontal, 12).padding(.vertical, 11)
      .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 11))
      .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(
        searchFocused ? Color.authAccent.opacity(0.5) : Color.authLine))
      .onExitCommand { store.query = "" }
  }

  private var accountList: some View {
    VStack(spacing: 0) {
      HStack(spacing: 4) {
        filter(L10n.text("全部账户"), favorite: false)
        filter(L10n.text("已收藏"), favorite: true)
        Spacer()
        Text(String(format: "%02d", store.visibleAccounts.count))
          .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.authMuted)
          .accessibilityLabel(L10n.text("\(store.visibleAccounts.count) 个"))
      }.padding(.horizontal, 20).padding(.bottom, 10)
      if store.visibleAccounts.isEmpty {
        Spacer()
        Image(systemName: "magnifyingglass").font(.system(size: 26)).foregroundStyle(.tertiary)
        Text(L10n.text("没有找到匹配的账户")).font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 10)
        Button(L10n.text("查看全部账户")) {
          store.query = ""
          store.favoritesOnly = false
        }.buttonStyle(.plain).foregroundStyle(Color.authAccent).padding(.top, 8)
        Spacer()
      } else {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          ScrollView {
            LazyVStack(spacing: 11) {
              ForEach(store.visibleAccounts) { account in
                AccountCard(
                  account: account, date: context.date, copied: store.copiedID == account.id,
                  copy: { store.copy(account) }, favorite: { store.toggleFavorite(account) }
                )
                .contextMenu {
                  Button(L10n.text("复制验证码")) { store.copy(account) }
                  Button(account.favorite ? L10n.text("取消收藏") : L10n.text("收藏账户")) { store.toggleFavorite(account) }
                  if account.kind == .hotp { Button(L10n.text("下一个 HOTP 验证码…")) { advancing = account } }
                  Divider()
                  Button(L10n.text("移除账户…"), role: .destructive) { deleting = account }
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
      .foregroundStyle(store.favoritesOnly == favorite ? Color.authAccent : Color.authMuted)
      .background(
        store.favoritesOnly == favorite ? Color.authAccent.opacity(0.13) : .clear,
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
      Text(L10n.text("把验证码带到菜单栏")).font(.system(size: 19, weight: .semibold)).padding(.top, 20)
      Text(L10n.text("导入 Chrome 身份验证器的备份，\n下次登录，点一下就好。")).font(.system(size: 12)).foregroundStyle(.secondary)
        .multilineTextAlignment(.center).lineSpacing(5).padding(.top, 9)
      Button(action: importAction) {
        Label(L10n.text("导入我的账户"), systemImage: "square.and.arrow.down").padding(.horizontal, 15).padding(
          .vertical, 5)
      }
      .buttonStyle(AuthPrimaryButtonStyle()).controlSize(.large).padding(.top, 24)
      Text(L10n.text("支持 JSON / TXT · 密码保护备份")).font(.system(size: 10)).foregroundStyle(.tertiary).padding(
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
      Text(L10n.text("验证码已锁定")).font(.system(size: 19, weight: .semibold))
      Text(L10n.text("使用 Touch ID 或 Mac 登录密码继续")).font(.system(size: 12)).foregroundStyle(.secondary)
      Button(store.isUnlocking ? L10n.text("正在验证…") : L10n.text("解锁")) { store.unlock() }.buttonStyle(AuthPrimaryButtonStyle())
        .controlSize(.large).disabled(store.isUnlocking)
      Spacer()
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var loadError: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: "exclamationmark.lock").font(.system(size: 36)).foregroundStyle(.orange)
      Text(L10n.text("暂时无法读取账户")).font(.headline)
      Text(L10n.text("请检查钥匙串权限，然后重试。\n现有账户不会被覆盖。")).multilineTextAlignment(.center).foregroundStyle(.secondary)
      Button(L10n.text("重新读取")) { store.reload() }.buttonStyle(AuthPrimaryButtonStyle())
      Spacer()
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Button(action: importAction) {
        Label(L10n.text("添加账户"), systemImage: "plus").font(.system(size: 11, weight: .medium))
      }
      .buttonStyle(AuthToolbarButtonStyle()).disabled(
        store.isLocked || store.loadFailed)
      Button(action: exportAction) {
        Label(L10n.text("导出备份"), systemImage: "square.and.arrow.up")
          .font(.system(size: 11, weight: .medium))
      }
      .buttonStyle(AuthToolbarButtonStyle())
      .disabled(store.isLocked || store.loadFailed || store.accounts.isEmpty)
      .help(store.isLocked ? L10n.text("解锁后导出备份") : (store.accounts.isEmpty ? L10n.text("添加账户后即可导出") : L10n.text("导出全部账户")))
      Spacer()
      Text(
        "v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L10n.text("开发版"))"
      )
      .font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.authMuted)
      Menu {
        Picker(L10n.text("语言 / Language"), selection: $store.language) {
          Text(L10n.text("跟随系统")).tag("system")
          Text("English").tag("en")
          Text("简体中文").tag("zh-Hans")
        }
        Divider()
        Button(L10n.text("添加账户 / 导入…"), action: importAction).disabled(store.isLocked || store.loadFailed)
        Button(L10n.text("导出备份…"), action: exportAction).disabled(
          store.isLocked || store.loadFailed || store.accounts.isEmpty)
        Button(L10n.text("锁定验证码")) { store.lock() }.disabled(store.isLocked || store.demo)
        Divider()
        Button(SMAppService.mainApp.status == .enabled ? L10n.text("关闭登录时启动") : L10n.text("登录时启动"), action: loginAction)
          .disabled(store.demo)
        Divider()
        Button(L10n.text("退出 Quick Auth")) { NSApp.terminate(nil) }.keyboardShortcut("q")
      } label: {
        Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(.secondary)
      }
      .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(L10n.text("设置"))
    }.padding(.horizontal, 20).padding(.vertical, 14)
      .background(Color.black.opacity(0.16))
      .overlay(alignment: .top) { Rectangle().fill(Color.authLine).frame(height: 1) }
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
  private var formattedCode: String {
    let code = account.code(at: date)
    if account.kind == .steam { return code }
    let middle = code.index(code.startIndex, offsetBy: code.count / 2)
    return String(code[..<middle]) + " " + String(code[middle...])
  }

  var body: some View {
    VStack(spacing: 17) {
      HStack(spacing: 9) {
        Text(String(account.title.prefix(1)).uppercased()).font(
          .system(size: 13, weight: .medium, design: .monospaced)
        )
        .foregroundStyle(Color.authAccent).frame(width: 34, height: 34)
        .background(Color.authAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.authAccent.opacity(0.17)))
        VStack(alignment: .leading, spacing: 3) {
          Text(account.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
          Text(account.subtitle).font(.system(size: 10)).foregroundStyle(Color.authMuted).lineLimit(1)
        }
        Spacer(minLength: 0)
        Text(account.kind.rawValue.uppercased())
          .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.7)
          .foregroundStyle(Color.authBlue.opacity(0.85)).padding(.horizontal, 6).padding(.vertical, 4)
          .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.authBlue.opacity(0.17)))
        Button(action: favorite) {
          Image(systemName: account.favorite ? "star.fill" : "star").font(.system(size: 11))
            .foregroundStyle(
              account.favorite
                ? Color.authAccent : Color.authMuted.opacity(hovering ? 1 : 0.5))
        }.buttonStyle(.plain).help(account.favorite ? L10n.text("取消收藏") : L10n.text("收藏"))
      }
      HStack {
        Button(action: copy) {
          HStack(spacing: 9) {
            Text(formattedCode).font(
              .system(size: account.digits > 8 ? 23 : 30, weight: .medium, design: .monospaced)
            ).tracking(2.0).monospacedDigit()
            Image(systemName: copied ? "checkmark" : "square.on.square").font(.system(size: 12))
              .opacity(copied || hovering ? 1 : 0.3)
          }.foregroundStyle(copied ? Color.authAccent : Color.authText)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).help(copied ? L10n.text("已复制 · 30 秒后自动清除") : L10n.text("复制验证码"))
          .accessibilityLabel(L10n.text("复制 \(account.title) 的验证码"))
        Spacer(minLength: 4)
        if account.kind == .hotp {
          Text("HOTP").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        } else {
          ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1.5)
            Circle().trim(from: 0, to: Double(remaining) / Double(account.period))
              .stroke(
                remaining <= 5 ? Color.orange.opacity(0.85) : Color.authAccent.opacity(0.8),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
              ).rotationEffect(.degrees(-90))
            Text("\(remaining)").font(.system(size: 9, weight: .medium, design: .monospaced))
              .foregroundStyle(Color.authAccent)
          }.frame(width: 30, height: 30).help(L10n.text("\(remaining) 秒后刷新"))
        }
      }
    }.padding(16)
      .background(
        LinearGradient(colors: [Color.white.opacity(hovering ? 0.085 : 0.055),
                                Color.white.opacity(0.018)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 15))
      .overlay(
        RoundedRectangle(cornerRadius: 15).strokeBorder(
          copied ? Color.authAccent.opacity(0.65) : (hovering ? Color.authAccent.opacity(0.32) : Color.authLine))
      )
      .onHover { hovering = $0 }
  }
}
