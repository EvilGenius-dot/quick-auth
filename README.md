# Quick Auth

原生 macOS 菜单栏二步验证器。点击顶部菜单栏的盾牌图标，搜索账户并复制当前验证码。

## 运行

双击 `dist/Quick Auth.app`。首次启动会自动打开菜单栏弹窗。

需要 macOS 13 或更高版本。当前生成的应用面向本机 Apple Silicon；在 Intel Mac 上执行同样的构建脚本即可生成 Intel 版本。可以把 `.app` 拖入「应用程序」文件夹，再从齿轮菜单开启「登录时启动」。当前是本机构建、临时签名版本，尚未进行 Developer ID 签名和 Apple 公证。

## 从 Chrome 迁移

适配插件：**Authenticator / 身份验证器**，ID `bhghoamapcdpbohphigoooaddinpkbai`。

1. 在 Chrome 插件打开「设置 → 备份」，下载备份文件或密码保护备份。
2. 点击 Quick Auth 菜单栏图标 →「添加账户」→「备份文件」，选择 `.json` 或 `.txt` 文件。
3. 加密备份会要求输入原插件的备份密码；解密完全在本机完成。
4. 检查账户预览，点击「导入」。重复密钥及相同验证码参数会自动去重，不覆盖现有账户，也不会回退 HOTP 计数器。
5. 对照原插件检查验证码。确认迁移成功前保留原插件和备份。

也可在「粘贴链接」页签中粘贴每行一个的 `otpauth://` 链接，或 JSON 备份文本。不需要把真实备份发送到聊天中。

## 手动添加与二维码

- **手动输入**：在「添加账户 → 手动输入」填写第三方网站提供的设置密钥、服务名和账号。支持 Base32 / 十六进制密钥，以及 TOTP / HOTP / Steam。一般使用默认的 TOTP、SHA1、6 位、30 秒；仅在服务明确指定时修改参数。
- **二维码图片**：在「添加账户 → 二维码」选择 PNG、JPEG、HEIC 或 TIFF 图片；一张图含多个二维码时会一起预览。
- **粘贴截图**：按 Control + Shift + Command + 4 截取二维码到剪贴板，再点击「粘贴截图」。
- **屏幕扫码**：先在浏览器中显示二维码，再点击「屏幕扫码」。应用暂时隐藏，使用 macOS 原生截图选区框住二维码，识别后自动回到预览；按 Esc 取消。首次需要允许系统「屏幕录制」权限。只识别你框选的区域，临时图片放在仅当前用户可访问的目录，识别或取消后删除，不上传。无需摄像头权限。

二维码支持标准 `otpauth://` 账户；Google Authenticator 的 `otpauth-migration://` 批量迁移码暂不支持。二维码中的普通网址不会被打开。

## 导出备份

点击齿轮菜单 →「导出备份…」，导出全部账户：

- **密码加密（默认）**：Quick Auth 自有 JSON 格式，使用 PBKDF2-HMAC-SHA256（600,000 次迭代、随机 16 字节盐）与 AES-256-GCM。账户名称、密钥和参数全部加密，密码或内容错误会导致解密失败。请保管好导出密码；可通过「备份文件」重新导入 Quick Auth，此格式不能直接导入 Chrome 插件。
- **明文（兼容 Chrome 插件）**：Authenticator JSON 格式。需要勾选确认后才可导出，文件含全部密钥。可用于迁移回原插件或支持该格式的验证器。

默认保存位置为「下载」，由你选择最终位置。文件仅限当前用户读写（0600），通过临时文件原子替换，导出失败不会覆盖原文件。导出不会移除本机账户。

## 日常使用

- 搜索服务名、账号或邮箱；按回车复制搜索结果中的第一个账户。
- 点击验证码复制，30 秒后仅清除仍属于本应用的剪贴板内容。
- 每个账户独立显示刷新倒计时；点击星标收藏并置顶。
- 右键账户可移除；HOTP 账户通过右键「下一个 HOTP 验证码」推进计数器，复制本身不推进。
- 齿轮菜单可锁定验证码。锁屏、休眠或切换用户时也会锁定，用 Touch ID 或 Mac 登录密码解锁。
- 应用没有 Dock 图标；退出使用齿轮菜单中的「退出 Quick Auth」。

## 支持范围

| 内容 | 支持情况 |
| --- | --- |
| Authenticator 普通 TXT / JSON 备份 | 支持 |
| Authenticator v1 / v2 / v3 密码保护 JSON | 支持；CryptoJS AES 与 Argon2id |
| TOTP / HOTP | 支持 SHA1 / SHA256 / SHA512，6–10 位，自定义周期 |
| Steam / Battle.net / 十六进制密钥 | 支持插件相应账户格式 |
| GOST 算法 | 暂不支持，预览中明确列出 |
| 手动设置密钥 / 图片与剪贴板二维码 / 屏幕框选扫码 | 支持 |
| Quick Auth 加密备份导入、导出 | 支持 |
| Authenticator 明文 JSON 导出 | 支持 |
| Google 批量迁移二维码 | 暂不支持 |
| 云同步、跨设备自动同步 | 暂未实现；可通过加密备份手动迁移 |

未知或损坏的记录会显示在预览中；只有明确勾选跳过无效记录，才允许部分导入。加密记录解密失败会终止整次预览，不静默丢弃账户。单次文件上限 5 MB、5000 个 JSON 账户。

## 数据存储

日常账户和密钥存入本机 macOS 登录钥匙串的 `local.quickauth.vault / accounts-v1` 项目，不另建明文账户数据库，也不启用钥匙串同步。可在「钥匙串访问」搜索 `Quick Auth` 查看对应项目。登录钥匙串通常位于 `~/Library/Keychains/login.keychain-db`，整个数据库由 macOS 管理，不应复制进项目或手动编辑。

导入只读取所选备份，原文件仍留在原位置；不会复制到工程目录。只有主动使用导出功能时才会生成备份文件，位置由保存对话框决定。导入和导出密码均不保存。应用没有网络请求或遥测。系统时间决定 TOTP 验证码，请保持 Mac 自动设置日期与时间。

锁定用于保护界面与内存中的账户可见性；解锁时通过 macOS 身份验证，再从钥匙串加载。剪贴板标记为敏感和临时内容；第三方剪贴板管理器是否遵守该标记由其实现决定。

## 开发与构建

依赖 Xcode 命令行工具 / Swift 5.9+；无在线 Swift 包依赖。

```bash
bash scripts/swift.sh test
bash scripts/build-app.sh
open "dist/Quick Auth.app"
```

可选真实钥匙串集成测试使用随机名称的临时项目，测试结束后清理：

```bash
QUICKAUTH_TEST_KEYCHAIN=1 bash scripts/swift.sh test --filter VaultTests
```

如在受限沙箱中执行，钥匙串、Vision 二维码图像识别测试和 `iconutil` 需要允许访问对应 macOS 服务。图标已包含在 `Resources/AppIcon.icns`，普通构建无需重新生成。

测试覆盖 RFC 6238 全部 SHA 测试向量、RFC 4226 HOTP 向量、时间边界、Base32、去重、参数验证、错误密码、加密损坏以及插件三代加密备份。加密测试样本使用 **CryptoJS 4.2.0 和 argon2-browser 1.18.0** 生成，只包含公开虚构密钥；`scripts/generate-fixtures.cjs` 记录了生成方式。

新增测试还验证加密与明文导出往返、GCM 篡改检测、随机盐和 nonce、手动参数校验、真实二维码图片识别、多码过滤，以及备份文件权限与原子替换。屏幕框选需在本机允许屏幕录制权限后使用；无需开启摄像头。

无持久化的界面演示：

```bash
open -n "dist/Quick Auth.app" --args --demo
```

开发者签名可通过 `QUICKAUTH_SIGNING_IDENTITY` 环境变量指定；跨设备分发仍需单独完成签名与公证流程。

## Git 与隐私

仓库：<https://github.com/EvilGenius-dot/quick-auth>

`.gitignore` 默认排除本地备份目录、JSON/TXT 备份、二维码图片、钥匙串和数据库文件、环境变量文件、证书私钥、构建产物及 ZIP。仅明确列出的四个公开虚构测试 JSON 样本允许提交。新增公开的 JSON/图片资源时，应单独审核并添加例外。

系统钥匙串不在仓库目录内。不要使用 `git add -f` 强行提交真实备份、密钥或二维码。

## 格式与实现参考

- [插件官方备份说明](https://authenticator.cc/docs/en/export-and-import.html)
- [标准 otpauth 文本备份](https://authenticator.cc/docs/en/otp-backup-developer.html)
- [插件加密与导入实现](https://github.com/Authenticator-Extension/Authenticator/blob/dev/src/import.ts)
- [RFC 6238](https://www.rfc-editor.org/rfc/rfc6238)、[RFC 4226](https://www.rfc-editor.org/rfc/rfc4226)
- 第三方代码来源见 `THIRD_PARTY.md`。
