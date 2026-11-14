## Quick Auth 1.2.1

### Black glass

- A new black frosted-glass interface across macOS and Windows, replacing the teal theme.
- Electric-blue and violet accents, translucent outlined cards, crisp monospaced codes and subtle countdown rings.
- Matching dark import, export and settings screens, plus refreshed app icons and bilingual README previews.
- Native macOS vibrancy and Windows 11 22H2+ Acrylic. Reduced transparency and older Windows versions use an opaque dark backdrop.

Existing accounts and encrypted backups remain compatible. Both English and Simplified Chinese are supported.

### Downloads

- **Quick-Auth-macOS-universal.dmg** — macOS 13+, Apple Silicon / Intel. Drag Quick Auth into Applications.
- **Quick-Auth-Windows-x64.exe** — Windows 10 / 11 x64 installer.
- **Quick-Auth-Windows-x64.zip** — extract the entire folder and launch Quick Auth.exe.
- **SHA256SUMS.txt** — SHA-256 checksums for all packages.

Quit an older running copy before opening the new app. The footer should show **v1.2.1**.

### Verification and signing

The build pipeline runs Swift and Node tests, cross-platform backup round trips, Windows DPAPI / UI / QR checks and a packaged Windows executable smoke test. UI previews use fictional accounts only.

macOS uses an ad-hoc signature and is not notarized; Windows is unsigned. System security prompts may appear. Download from this repository and compare the SHA-256 checksum.

---

### 中文

- Mac 与 Windows 全面换成黑色毛玻璃主题，移除青绿色配色。
- 电光蓝和紫色点缀、半透明细边框卡片、清晰的等宽验证码及精简倒计时。
- 导入、导出、设置、应用图标及中英文 README 预览图同步更新。
- macOS 使用原生毛玻璃，Windows 11 22H2 及以上使用 Acrylic；旧系统或降低透明度时使用纯深色背景。

原有账户和加密备份继续兼容，保留中英文切换。安装后请退出旧版本，再启动新版本，底部应显示 **v1.2.1**。

提供 macOS 通用 DMG（Apple Silicon / Intel）、Windows x64 安装程序和 ZIP，以及 SHA-256 校验值。当前 macOS 包尚未公证，Windows 包未签名。
