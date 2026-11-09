<p align="center">
  <img src="docs/assets/app-icon.png" alt="Quick Auth 图标" width="88" height="88">
</p>

<h1 align="center">Quick Auth</h1>

<p align="center">
  <strong>验证码，随手可得。</strong><br>
  一个原生 macOS 菜单栏二步验证器，让搜索、复制、迁移与备份都在本机完成。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-151f1b?style=flat-square&amp;logo=apple&amp;logoColor=white" alt="macOS 13 或更高版本">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-f07143?style=flat-square&amp;logo=swift&amp;logoColor=white" alt="Swift 5.9 或更高版本">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-208d77?style=flat-square" alt="SwiftUI 与 AppKit">
  <img src="https://img.shields.io/badge/Storage-macOS%20Keychain-208d77?style=flat-square" alt="数据保存在 macOS 钥匙串">
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> ·
  <a href="#添加与迁移">添加与迁移</a> ·
  <a href="#导出备份">导出备份</a> ·
  <a href="#隐私与存储">隐私与存储</a> ·
  <a href="#开发与验证">开发与验证</a>
</p>

<p align="center">
  <img src="docs/assets/overview.svg" alt="Quick Auth 功能示意：搜索验证码、添加账户与导出备份" width="100%">
  <br><sub>功能示意图 · 所有账户和验证码均为演示数据</sub>
</p>

## 功能概览

| | 你可以做什么 |
| :--- | :--- |
| **菜单栏随手用** | 点击顶部盾牌图标，搜索服务或账号，复制当前验证码；每个账户都有刷新倒计时。 |
| **多种方式添加** | 导入备份、粘贴账户链接、填写第三方设置密钥，或识别屏幕选区、图片和剪贴板中的二维码。 |
| **从 Chrome 迁移** | 兼容 Authenticator「身份验证器」的普通备份，以及 v1 / v2 / v3 密码保护备份。 |
| **随时备份** | 主面板底部直接导出；提供密码加密备份和兼容原插件的明文 JSON。 |
| **本机保管** | 账户存入系统钥匙串；支持手动锁定，锁屏、休眠或切换用户时自动锁定。 |
| **省一步操作** | 收藏常用账户、回车复制首个搜索结果、登录时自动启动；无需云端账户。 |

## 快速开始

### 从源码构建

准备 macOS 13+ 和带有 Swift 5.9+ 的 Xcode 命令行工具，然后运行：

```bash
git clone https://github.com/EvilGenius-dot/quick-auth.git
cd quick-auth
bash scripts/build-app.sh
open "dist/Quick Auth.app"
```

构建不需要下载在线 Swift 包，Argon2 源码已随仓库提供。应用会生成在 `dist/Quick Auth.app`，可以将它拖入「应用程序」文件夹。

### 第一次打开

1. 点击顶部菜单栏的 **盾牌图标**。Quick Auth 不显示 Dock 图标。
2. 点击底部 **「添加账户」**，选择适合你的添加方式。
3. 检查账户预览并保存；点击验证码即可复制。
4. 点击底部 **「导出备份」**，保存一份可恢复的备份。

> **更新已有应用：** 先从齿轮菜单退出旧版，再打开新构建的应用。账户保存在系统钥匙串中，替换 `.app` 不会删除账户。底部显示当前版本，便于确认是否打开了新版。

当前构建使用本机架构：Apple Silicon Mac 生成 arm64 应用，Intel Mac 可从源码构建。仓库不包含通用二进制安装包；本机构建默认采用临时签名，尚未完成 Developer ID 签名和 Apple 公证。

## 添加与迁移

点击 **添加账户**，窗口提供四个页签：

| 页签 | 适用场景 |
| :--- | :--- |
| **备份文件** | 导入 Quick Auth 的加密备份，或 Chrome Authenticator 导出的 `.json` / `.txt`。 |
| **粘贴链接** | 粘贴每行一个的 `otpauth://` 链接，也可粘贴 JSON 备份文本。 |
| **手动输入** | 填写网站或 App 提供的设置密钥、服务名与账号。 |
| **二维码** | 框选屏幕二维码、选择二维码图片，或粘贴截图。 |

### 从 Chrome「身份验证器」迁移

适配 [Authenticator（authenticator.cc）](https://authenticator.cc/)：

```text
扩展 ID：bhghoamapcdpbohphigoooaddinpkbai
```

1. 在插件中打开 **设置 → 备份**，下载普通备份或密码保护备份。
2. 在 Quick Auth 中选择 **添加账户 → 备份文件**，打开导出的文件。
3. 若备份已加密，输入导出时使用的密码；解密在本机完成。
4. 检查账户列表，再点击 **导入**。相同密钥与验证码参数会自动去重。

现有账户会保留，重复导入不会回退 HOTP 计数器。无法识别的记录会列在预览中；部分导入需要明确勾选跳过无效记录。加密记录解密失败会终止预览。

迁移后请对照原插件检查验证码，在确认成功前保留原插件和备份。参见 [插件官方导出说明](https://authenticator.cc/docs/en/export-and-import.html)。

### 手动输入第三方密钥

输入服务提供的 **设置密钥**，而非当前显示的六位验证码。默认使用 **TOTP · SHA1 · 6 位 · 30 秒**；如果服务指定了其他算法、周期或 HOTP 计数器，再修改对应参数。

支持 Base32 和十六进制密钥，以及 TOTP、HOTP 和 Steam 账户。

### 屏幕二维码

1. 在浏览器或其他应用中显示二步验证二维码。
2. 选择 **添加账户 → 二维码 → 屏幕扫码**。
3. Quick Auth 暂时隐藏，拖动 macOS 原生选框圈住二维码。
4. 识别完成后自动返回账户预览；按 **Esc** 可取消。

首次使用需要在系统设置中允许 **屏幕录制** 权限。屏幕扫码只处理你框选的区域，无需摄像头。

也可选择 PNG、JPEG、HEIC、TIFF 图片，或按 **⌃ Control + ⇧ Shift + ⌘ Command + 4** 截图到剪贴板后点击 **「粘贴截图」**。标准 `otpauth://` 二维码可直接识别；普通网址不会被打开。

## 导出备份

点击主面板底部的 **「导出备份」**。齿轮菜单中也保留同名入口。账户为空、应用锁定或钥匙串读取失败时，按钮不可用。

| 格式 | 适合用途 | 恢复方式 |
| :--- | :--- | :--- |
| **密码加密 · 默认** | 日常备份、通过文件迁移到另一台 Mac | 使用 Quick Auth 导入，并输入备份密码。 |
| **明文 · 兼容 Chrome 插件** | 迁移回 Authenticator 或其他兼容工具 | 按 Authenticator JSON 格式导入。 |

- 导出包含全部账户及其算法、周期、收藏状态和 HOTP 计数器，不会移除本机账户。
- 保存对话框默认指向「下载」，最终保存位置由你选择。
- 密码加密格式是 **Quick Auth 自有格式**，不能直接导回 Chrome 插件；请保管好密码，忘记后无法解密。
- 明文格式包含全部账户密钥，需要勾选确认才可导出；仅用于你能妥善保管的迁移场景。

<details>
<summary><strong>加密与文件写入细节</strong></summary>

加密备份使用 PBKDF2-HMAC-SHA256（600,000 次迭代、随机 16 字节盐）派生密钥，再使用 AES-256-GCM 加密。账户名称、密钥与验证码参数均在密文中，错误密码或密文篡改会导致解密失败。

备份通过权限为 `0600` 的临时文件写入并原子替换，避免导出失败时损坏已有备份。实现见 [BackupExporter.swift](Sources/QuickAuthCore/BackupExporter.swift) 与 [BackupFileWriter.swift](Sources/QuickAuthCore/BackupFileWriter.swift)。

</details>

## 隐私与存储

**应用没有网络请求、遥测或云同步。** 日常账户保存在 macOS 登录钥匙串，不在工程目录中创建账户数据库。

| 数据 | 保存位置与行为 |
| :--- | :--- |
| 账户与密钥 | 系统登录钥匙串，条目为 `local.quickauth.vault / accounts-v1`；不启用钥匙串同步。 |
| 原始导入文件 | 保留在原位置；应用只读取，不复制到项目目录。 |
| 导出的备份 | 只有主动导出才生成，位置由保存对话框决定。 |
| 屏幕扫码图片 | 暂存于仅当前用户可访问的临时目录，完成或取消后删除，不上传。 |
| 备份密码 | 仅用于本次导入或导出，不持久保存。 |
| 复制的验证码 | 30 秒后，仅在剪贴板仍是本次复制内容时清除，避免清掉你后续复制的其他文本。 |

在 **钥匙串访问** 中搜索 `Quick Auth` 可以找到对应项目。登录钥匙串通常位于 `~/Library/Keychains/login.keychain-db`，由 macOS 管理，不应手动编辑或提交到 Git。

锁定后通过 Touch ID 或 Mac 登录密码验证身份，再从钥匙串加载账户。剪贴板会标记为敏感和临时内容；第三方剪贴板工具是否遵守这些标记，取决于其自身实现。

## 兼容范围

| 能力 | 状态 |
| :--- | :--- |
| TOTP / HOTP，SHA1 / SHA256 / SHA512 | 支持 |
| 6–10 位数字验证码、自定义周期 | 支持 |
| Steam / Battle.net / 十六进制密钥 | 支持对应账户格式 |
| Authenticator 普通 TXT / JSON、v1 / v2 / v3 加密 JSON | 支持导入 |
| Quick Auth 加密 JSON | 支持导入、导出 |
| Authenticator 明文 JSON | 支持导出 |
| 标准 `otpauth://` 链接与二维码 | 支持 |
| Google Authenticator 批量迁移二维码 | 暂不支持 |
| GOST 算法 | 暂不支持；预览中明确列出 |
| 云同步、跨设备自动同步 | 暂不支持；可通过加密备份手动迁移 |

文件备份上限为 **5 MB**，单次 JSON 导入最多 **5000 个账户**；二维码图片上限为 **20 MB**。

## 常见问题

<details>
<summary><strong>为什么看不到「导出备份」？</strong></summary>

请确认底部版本号为 **v1.1.1 或更高版本**。1.0.0 没有导出功能；1.1.0 的导出入口位于齿轮菜单；1.1.1 起主面板底部也有独立按钮。

退出旧进程后再打开新构建的 `dist/Quick Auth.app`。如果同时保存了多份 `.app`，请确认启动的是最新那一份。

</details>

<details>
<summary><strong>验证码与服务端不一致怎么办？</strong></summary>

先确认 Mac 已启用自动设置日期与时间，再检查账户的算法、位数和刷新周期是否与服务要求一致。HOTP 不会随时间刷新；仅在当前验证码已使用后，通过账户右键菜单推进计数器。

</details>

<details>
<summary><strong>替换应用、重新构建会丢失账户吗？</strong></summary>

不会因为替换 `.app` 而删除系统钥匙串中的账户。代码签名发生变化时，macOS 可能重新询问钥匙串访问权限。请保留自己的加密备份，以便迁移或恢复。

</details>

<details>
<summary><strong>扫描屏幕失败怎么办？</strong></summary>

检查「系统设置 → 隐私与安全性 → 屏幕录制」中的授权，按系统提示重新打开应用；也可使用图片导入或粘贴截图。框选时应包含完整二维码及周围留白，避免选区过大或二维码模糊。

</details>

## 开发与验证

```bash
# 核心算法、导入导出、手动输入与二维码识别
bash scripts/swift.sh test

# 额外运行系统钥匙串读写测试（只使用临时虚构账户，结束后清理）
QUICKAUTH_TEST_KEYCHAIN=1 bash scripts/swift.sh test

# 编译并打包应用
bash scripts/build-app.sh

# 演示模式：使用虚构账户，不读取或保存真实账户
open -n "dist/Quick Auth.app" --args --demo
```

测试覆盖 RFC 6238 全部 SHA 测试向量、RFC 4226 HOTP、Base32、时间边界、去重、三代插件加密备份、导出往返、GCM 篡改检测、手动参数校验、二维码图片识别和备份文件权限。测试样本使用公开虚构密钥，其中插件加密备份由 CryptoJS 与 argon2-browser 生成。

在受限沙箱中运行时，Vision 图像识别和钥匙串测试需要访问对应 macOS 系统服务。屏幕框选的系统权限与交互需在本机验证。

<details>
<summary><strong>目录结构与构建选项</strong></summary>

```text
Sources/
├── QuickAuth/             # 菜单栏界面、导入导出窗口、屏幕框选
├── QuickAuthCore/         # OTP 算法、格式解析、加密备份与钥匙串
└── CArgon2/               # 插件旧备份兼容所需的 Argon2 参考实现
Tests/QuickAuthCoreTests/  # 算法、导入导出、二维码与存储测试
docs/assets/              # 公开的图标和演示插图
Resources/                # 应用图标、Info.plist
scripts/                  # 构建、图标与测试样本生成
```

- `QUICKAUTH_APP_OUTPUT`：指定 `.app` 的输出路径。
- `QUICKAUTH_SIGNING_IDENTITY`：指定签名身份，默认使用本地临时签名。
- 跨设备分发需自行完成 Developer ID 签名、公证及对应架构构建。

</details>

`.gitignore` 排除了备份、二维码截图、钥匙串、数据库、环境变量、证书私钥及构建产物。只有明确列出的公开测试 JSON 与应用图标例外；请勿使用 `git add -f` 提交真实密钥或备份。

## 版本记录

| 版本 | 变化 |
| :--- | :--- |
| **1.1.1** | 主面板增加「导出备份」按钮和版本号；完善 GitHub 使用文档。 |
| **1.1.0** | 加密与明文导出、手动密钥添加、屏幕框选二维码、图片与剪贴板识别。 |
| **1.0.0** | 菜单栏验证码、搜索复制、Chrome 备份导入、钥匙串存储与锁定。 |

## 参考与第三方代码

- [Authenticator 官方备份说明](https://authenticator.cc/docs/en/export-and-import.html) · [标准备份格式](https://authenticator.cc/docs/en/otp-backup-developer.html)
- [Authenticator 导入实现](https://github.com/Authenticator-Extension/Authenticator/blob/dev/src/import.ts)
- [RFC 6238 · TOTP](https://www.rfc-editor.org/rfc/rfc6238) · [RFC 4226 · HOTP](https://www.rfc-editor.org/rfc/rfc4226)
- [第三方代码与许可证说明](THIRD_PARTY.md)

---

<p align="center">
  Quick Auth · 留在菜单栏，也留在本机。<br>
  <a href="https://github.com/EvilGenius-dot/quick-auth/issues">反馈问题</a> ·
  <a href="https://github.com/EvilGenius-dot/quick-auth">查看源码</a>
</p>
