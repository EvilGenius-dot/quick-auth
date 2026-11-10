## Quick Auth 1.2.0

English · [简体中文说明](https://github.com/EvilGenius-dot/quick-auth/blob/main/README.zh-CN.md)

### New

- English and Simplified Chinese interfaces on both platforms, with system-language detection and an immediate language switch in Settings.
- A Windows system tray app with search, favorites, copy, manual setup keys, Chrome backup import, screen-region QR scanning, image/clipboard QR import and backup export.
- Encrypted backups that restore across Mac and Windows, preserving account parameters, favorites and full UInt64 HOTP counters.
- A universal macOS DMG for Apple Silicon and Intel, plus a Windows x64 installer and ZIP.
- English default README, Chinese README, direct downloads and automated release builds.

### Downloads

- **Quick-Auth-macOS-universal.dmg** — macOS 13+, Apple Silicon / Intel. Drag Quick Auth into Applications.
- **Quick-Auth-Windows-x64.exe** — Windows 10 / 11 x64. Installer supports English and Chinese.
- **Quick-Auth-Windows-x64.zip** — extract the entire folder and launch Quick Auth.exe. Uses the same AppData vault as the installer.
- **SHA256SUMS.txt** — SHA-256 checksums for all packages.

### Storage and compatibility

The native Mac app continues using the existing Keychain item; upgrading preserves accounts. Windows encrypts its local vault with DPAPI under `%APPDATA%\Quick Auth`. Migrate with an encrypted export rather than copying the vault file. Chrome Authenticator plaintext and v1 / v2 / v3 encrypted backups remain supported. QR scanning uses the screen, not a camera.

Windows clears loaded accounts on Windows session lock and reloads after unlock. App-level Windows Hello verification is not included. Google bulk migration QR codes, GOST, cloud sync, Windows ARM64 packages and Linux packages are not included.

### Verification and signing

Builds run protocol tests, legacy Chrome backup fixtures, cross-language encrypted backup round trips, Windows DPAPI/UI/QR smoke checks and a packaged Windows executable smoke test before publication. Screen-selection permissions and monitor-specific behavior still depend on the local operating system and hardware.

These packages do **not** carry a commercial signing identity: macOS uses an ad-hoc signature and is not notarized; Windows is unsigned. System security prompts may appear. Download from this repository and compare the SHA-256 checksum.

---

### 中文

- 新增中文 / English / 跟随系统，设置中立即切换。
- 新增 Windows 托盘版，支持搜索、收藏、复制、手动输入、Chrome 备份导入、屏幕框选扫码、图片/剪贴板扫码及导出备份。
- Mac 与 Windows 的加密备份可互相恢复，保留账户参数、收藏和完整 HOTP 计数器。
- 提供 macOS 通用 DMG（Apple Silicon / Intel）、Windows x64 安装程序和 ZIP。
- 默认 README 使用英文，提供完整中文文档和直接下载入口。

Mac 原有钥匙串账户保留。Windows 账户使用 DPAPI 加密，存放于 `%APPDATA%\Quick Auth`；跨设备迁移请导出加密备份。二维码使用屏幕框选，不使用摄像头。

当前 macOS 包尚未公证，Windows 包未签名，系统可能显示安全提示。此版本不包含 Windows ARM64、Linux、Google 批量迁移二维码、云同步或应用内 Windows Hello。
