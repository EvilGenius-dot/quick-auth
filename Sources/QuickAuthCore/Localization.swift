import Foundation

/// Language selection is shared by the UI and validation errors. Secrets and
/// account names are never used as localization keys.
public enum L10n {
  public static var preference: String {
    get { UserDefaults.standard.string(forKey: "appLanguage") ?? "system" }
    set { UserDefaults.standard.set(newValue, forKey: "appLanguage") }
  }
  public static var language: String {
    resolved(preference: preference, preferredLanguages: Locale.preferredLanguages)
  }
  public static func resolved(preference: String, preferredLanguages: [String]) -> String {
    if preference == "en" { return "en" }
    if preference == "zh-Hans" { return "zh-Hans" }
    return preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh-Hans" : "en"
  }
  public static func text(_ value: LocalizedText) -> String { render(value, language: language) }
  public static func render(_ value: LocalizedText, language: String) -> String {
    let template = language == "zh-Hans" ? value.key : english[value.key] ?? value.key
    let parts = template.components(separatedBy: "%@")
    var output = parts[0]
    for (index, part) in parts.dropFirst().enumerated() {
      output += (index < value.arguments.count ? value.arguments[index] : "%@") + part
    }
    return output
  }
  static let english: [String: String] = [
    "操作未完成": "Action could not be completed",
    "好": "OK",
    "移除这个账户？": "Remove this account?",
    "取消": "Cancel",
    "移除": "Remove",
    "将从 Quick Auth 移除「%@」。请确认你仍保留原插件或备份。": "Remove “%@” from Quick Auth? Make sure you still have the original authenticator or a backup.",
    "生成下一个 HOTP 验证码？": "Generate the next HOTP code?",
    "下一个": "Next",
    "计数器会增加 1。仅在当前验证码已使用后继续，避免与服务端失去同步。": "The counter will increase by 1. Continue only after using the current code to avoid losing sync with the service.",
    "验证码，随手可得": "Your codes, one click away",
    "演示模式": "Demo",
    "仅本机": "On device",
    "搜索账户或服务…": "Search accounts or services…",
    "清除搜索": "Clear search",
    "↵ 复制": "↵ Copy",
    "全部账户": "All accounts",
    "已收藏": "Favorites",
    "%@ 个": "%@ items",
    "没有找到匹配的账户": "No matching accounts",
    "查看全部账户": "Show all accounts",
    "复制验证码": "Copy code",
    "取消收藏": "Unfavorite",
    "收藏账户": "Favorite account",
    "下一个 HOTP 验证码…": "Next HOTP code…",
    "移除账户…": "Remove account…",
    "把验证码带到菜单栏": "Your codes in the menu bar",
    "导入 Chrome 身份验证器的备份，\n下次登录，点一下就好。": "Import your Chrome Authenticator backup.\nYour next sign-in is just a click away.",
    "导入我的账户": "Import accounts",
    "支持 JSON / TXT · 密码保护备份": "JSON / TXT · Password-protected backups",
    "验证码已锁定": "Your codes are locked",
    "使用 Touch ID 或 Mac 登录密码继续": "Use Touch ID or your Mac login password to continue",
    "正在验证…": "Verifying…",
    "解锁": "Unlock",
    "暂时无法读取账户": "Accounts are unavailable",
    "请检查钥匙串权限，然后重试。\n现有账户不会被覆盖。": "Check Keychain access and try again.\nExisting accounts will not be overwritten.",
    "重新读取": "Try again",
    "添加账户": "Add account",
    "导出备份": "Export backup",
    "解锁后导出备份": "Unlock to export a backup",
    "添加账户后即可导出": "Add an account to enable export",
    "导出全部账户": "Export all accounts",
    "开发版": "dev",
    "添加账户 / 导入…": "Add account / Import…",
    "导出备份…": "Export backup…",
    "锁定验证码": "Lock codes",
    "关闭登录时启动": "Disable launch at login",
    "登录时启动": "Launch at login",
    "退出 Quick Auth": "Quit Quick Auth",
    "设置": "Settings",
    "收藏": "Favorite",
    "已复制 · 30 秒后自动清除": "Copied · Clears after 30 seconds",
    "复制 %@ 的验证码": "Copy code for %@",
    "%@ 秒后刷新": "Refreshes in %@ seconds",
    "请在系统设置 → 隐私与安全性 → 屏幕录制中允许 Quick Auth，然后重新打开应用。也可直接粘贴二维码截图。": "Allow Quick Auth in System Settings → Privacy & Security → Screen Recording, then reopen the app. You can also paste a QR screenshot.",
    "无法创建临时截图，请使用粘贴截图。": "Could not create a temporary screenshot. Try pasting an image.",
    "屏幕截取未完成，请重试。": "Screen capture did not complete. Please try again.",
    "选区过大，请仅框选二维码区域。": "The selection is too large. Select just the QR code.",
    "无法启动系统截图工具，请使用粘贴截图。": "Could not start the system screenshot tool. Try pasting an image.",
    "将全部 %@ 个账户保存到你选择的位置。": "Save all %@ accounts to a location you choose.",
    "备份格式": "Backup format",
    "密码加密 · 推荐": "Password encrypted · Recommended",
    "明文 · 兼容 Chrome 插件": "Plaintext · Chrome extension compatible",
    "备份密码（至少 8 个字符）": "Backup password (at least 8 characters)",
    "再次输入备份密码": "Confirm backup password",
    "用于 Quick Auth 恢复。请保管好密码，忘记后无法解密备份。": "Restore with Quick Auth. Keep this password safe: a forgotten password cannot be recovered.",
    "明文文件包含全部账户密钥": "Plaintext files contain all account secrets",
    "持有文件的人可以生成你的验证码。仅在迁移到其他验证器时使用，并保存在安全位置。": "Anyone with this file can generate your codes. Use it for migration and keep it in a secure location.",
    "我了解明文备份包含密钥": "I understand this backup contains account secrets",
    "导出在本机完成，文件不会上传。": "Exported locally. Your file is never uploaded.",
    "导出到文件…": "Export to file…",
    "（密码保护）": " (password protected)",
    "（明文）": " (plaintext)",
    "已导出 %@ 个账户%@": "Exported %@ accounts%@",
    "导出未完成：%@": "Export failed: %@",
    "账户尚未解锁或读取失败，请先恢复访问。": "Accounts are locked or could not be loaded. Restore access first.",
    "已导入 %@ 个账户，跳过 %@ 个重复账户": "Imported %@ accounts; skipped %@ duplicates",
    "计数器已达到上限。": "The counter has reached its maximum value.",
    "无法复制到剪贴板。": "Could not copy to the clipboard.",
    "系统身份验证不可用，请检查 Mac 的登录密码设置后重试。": "System authentication is unavailable. Check your Mac login password settings and try again.",
    "解锁 Quick Auth 验证码": "Unlock Quick Auth codes",
    "添加你的验证账户": "Add your accounts",
    "导入备份、填写密钥，或扫描二步验证二维码。": "Import a backup, enter a setup key, or scan a QR code.",
    "导入来源": "Import source",
    "备份文件": "Backup file",
    "粘贴链接": "Paste link",
    "手动输入": "Manual entry",
    "二维码": "QR code",
    "选择 Quick Auth / Authenticator 备份": "Choose a Quick Auth / Authenticator backup",
    "支持 .json、.txt 和密码保护备份": ".json, .txt and password-protected backups",
    "选择文件…": "Choose file…",
    "重新选择…": "Choose another…",
    "每行一个 otpauth:// 链接，也可粘贴 JSON 备份。": "Paste one otpauth:// link per line, or a JSON backup.",
    "此备份受密码保护": "This backup is password protected",
    "输入导出时设置的备份密码": "Enter the password used when exporting",
    "密码仅用于本次本机解密，不会保存。": "Used only to decrypt locally. Your password is not saved.",
    "导入预览": "Import preview",
    "新增 %@ · 重复 %@": "%@ new · %@ duplicates",
    "第 %@ 条：%@": "Record %@: %@",
    "跳过 %@ 条无法导入的记录，继续导入有效账户": "Skip %@ invalid records and import the valid accounts",
    "在 Chrome 插件中导出": "Export from the Chrome extension",
    "打开「身份验证器」→ 设置 → 备份 → 下载备份文件或下载密码保护备份。": "Open Authenticator → Settings → Backup → Download backup or password-protected backup.",
    "演示模式：本次导入不会保存": "Demo: imported accounts will not be saved",
    "密钥保存在 macOS 钥匙串 · 不上传任何数据": "Secrets stored in macOS Keychain · Nothing uploaded",
    "正在解析…": "Reading…",
    "完成（均已存在）": "Done (already imported)",
    "导入 %@ 个账户": "Import %@ accounts",
    "解密并预览": "Decrypt & preview",
    "预览账户": "Preview accounts",
    "输入网站或 App 在开启二步验证时提供的设置密钥。": "Enter the setup key provided by the website or app when enabling two-factor authentication.",
    "服务名称，例如 GitHub": "Service name, e.g. GitHub",
    "账号或邮箱": "Account or email",
    "设置密钥（不是当前的六位验证码）": "Setup key (not the current six-digit code)",
    "密钥编码": "Key encoding",
    "Base32（常用）": "Base32 (common)",
    "十六进制": "Hexadecimal",
    "验证码类型": "Code type",
    "基于时间 TOTP（常用）": "Time-based TOTP (common)",
    "基于计数 HOTP": "Counter-based HOTP",
    "算法": "Algorithm",
    "位数": "Digits",
    "%@ 位": "%@ digits",
    "初始计数器": "Initial counter",
    "刷新周期（秒）": "Refresh period (seconds)",
    "服务未指定参数时，使用 TOTP、SHA1、6 位、30 秒即可。": "Unless your service specifies otherwise, use TOTP, SHA1, 6 digits and 30 seconds.",
    "扫描服务提供的二步验证二维码，识别后先预览再保存。": "Scan the service’s two-factor QR code, then preview before saving.",
    "选择二维码图片…": "Choose QR image…",
    "粘贴截图": "Paste screenshot",
    "正在框选…": "Selecting…",
    "屏幕扫码": "Scan screen",
    "先在浏览器中显示二维码，再点击「屏幕扫码」并拖动框选二维码；按 Esc 取消。": "Show the QR code in your browser, click “Scan screen”, then drag to select it. Press Esc to cancel.",
    "支持标准 otpauth 二维码；暂不支持 Google 验证器的批量迁移二维码。": "Standard otpauth QR codes are supported. Google Authenticator bulk migration QR codes are not supported yet.",
    "二维码图片不能超过 20 MB。": "QR images must not exceed 20 MB.",
    "剪贴板中没有图片。可以按 Control + Shift + Command + 4 截取二维码后再粘贴。": "No image in the clipboard. Press Control + Shift + Command + 4 to capture a QR code, then paste it here.",
    "选择 Quick Auth 或 Chrome 身份验证器导出的备份": "Choose a backup exported by Quick Auth or Chrome Authenticator",
    "备份文件超过 5 MB，无法导入。": "The backup exceeds the 5 MB limit.",
    "无法读取备份：%@": "Could not read the backup: %@",
    "Quick Auth 身份验证器": "Quick Auth Authenticator",
    "Quick Auth · 身份验证器": "Quick Auth · Authenticator",
    "添加账户 · Quick Auth": "Add accounts · Quick Auth",
    "导出备份 · Quick Auth": "Export backup · Quick Auth",
    "已关闭登录时启动": "Launch at login disabled",
    "请在系统设置中允许登录项": "Allow the login item in System Settings",
    "已开启登录时启动": "Launch at login enabled",
    "无法设置登录项。请先把应用放入「应用程序」文件夹，再重试。": "Could not change the login item. Move the app into Applications, then try again.",
    "备份不是 UTF-8 文本文件。": "The backup is not a UTF-8 text file.",
    "JSON 备份格式错误，请重新从插件导出。": "Invalid JSON backup. Export a new copy from the extension.",
    "备份中的行数过多。": "The backup contains too many lines.",
    "不是支持的 otpauth 账户链接。": "This is not a supported otpauth account link.",
    "账户链接含重复或空参数。": "The account link contains duplicate or empty parameters.",
    "账户链接缺少密钥。": "The account link has no secret.",
    "不支持此验证码编码方式。": "This code encoding is not supported.",
    "HOTP 账户缺少计数器。": "The HOTP account has no counter.",
    "一次最多导入 5000 个账户。": "Import up to 5,000 accounts at a time.",
    "无法识别此记录。": "This record could not be recognized.",
    "账户参数 %@ 格式错误。": "Invalid account parameter: %@.",
    "不支持此账户类型。": "This account type is not supported.",
    "账户缺少密钥。": "The account has no secret.",
    "不支持此哈希算法（如 GOST）。": "This hash algorithm (such as GOST) is not supported.",
    "哈希算法格式错误。": "Invalid hash algorithm.",
    "账户参数 %@ 必须是整数。": "Account parameter %@ must be an integer.",
    "HOTP 计数器格式错误。": "Invalid HOTP counter.",
    "无法读取图片，请选择 PNG、JPEG、HEIC 或 TIFF 图片。": "Could not read the image. Choose a PNG, JPEG, HEIC or TIFF file.",
    "无法解码二维码图片。": "Could not decode the QR image.",
    "未识别到二维码，请使用清晰、完整的二维码图片。": "No QR code found. Use a clear image of the entire code.",
    "二维码不是受支持的二步验证账户（需要 otpauth 格式）。": "This QR code is not a supported two-factor account (otpauth required).",
    "一次最多导出 5000 个账户。": "Export up to 5,000 accounts at a time.",
    "备份过大，无法导出。": "The backup is too large to export.",
    "备份密码至少需要 8 个字符，且不能超过 4096 字节。": "Use at least 8 characters and no more than 4,096 UTF-8 bytes for the backup password.",
    "无法生成安全随机数，导出已取消。": "Could not generate secure random bytes. Export cancelled.",
    "无法加密备份。": "Could not encrypt the backup.",
    "加密备份超过 5 MB，无法导出。": "The encrypted backup exceeds the 5 MB limit.",
    "不支持或已损坏的 Quick Auth 加密备份。": "Unsupported or damaged Quick Auth encrypted backup.",
    "这是密码保护备份，请输入导出时设置的备份密码。": "This backup is password protected. Enter the password used when exporting.",
    "密码不正确，或加密备份已损坏。请检查密码和原始文件后重试。": "Wrong password or damaged encrypted backup. Check the password and original file, then try again.",
    "备份中没有找到可导入的账户。请选择 Authenticator 导出的 JSON 或 TXT 文件。": "No accounts found. Choose a JSON or TXT backup exported by Authenticator.",
    "密钥为空或过长。": "The secret is empty or too long.",
    "不支持的验证码位数（支持 6–10 位）。": "Unsupported code length (6–10 digits supported).",
    "验证码周期必须在 1–86400 秒之间。": "The code period must be between 1 and 86,400 seconds.",
    "账户名称过长。": "The account name is too long.",
    "未命名账户": "Unnamed account",
    "身份验证器": "Authenticator",
    "密钥不是有效的 Base32 文本。": "The secret is not valid Base32 text.",
    "密钥包含无效字符。": "The secret contains invalid characters.",
    "密钥长度或末尾填充无效。": "Invalid secret length or trailing padding.",
    "十六进制密钥长度无效。": "Invalid hexadecimal secret length.",
    "十六进制密钥包含无效字符。": "The hexadecimal secret contains invalid characters.",
    "钥匙串中的账户数据无法读取。为保护原数据，已暂停写入。": "Could not read account data from Keychain. Writes are paused to protect existing data.",
    "账户数据存在重复标识，已暂停写入。": "Duplicate account identifiers found. Writes are paused.",
    "Quick Auth · 身份验证账户": "Quick Auth · Authentication accounts",
    "无法访问系统钥匙串（%@）。请解锁登录钥匙串或允许 Quick Auth 访问后重试。": "Could not access Keychain (%@). Unlock the login keychain or allow Quick Auth to access it, then retry.",
    "无法在所选文件夹创建备份。": "Could not create a backup in the selected folder.",
    "无法保存备份文件，原文件未被修改。": "Could not save the backup. The original file has not been changed.",
    "请填写服务名称或账号。": "Enter a service name or account.",
    "刷新周期应为 1–86400 秒的整数。": "The refresh period must be an integer between 1 and 86,400 seconds.",
    "计数器应为非负整数。": "The counter must be a non-negative integer.",
    "语言 / Language": "Language / 语言",
    "跟随系统": "System default",
  ]
}

public struct LocalizedText: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
  let key: String
  let arguments: [String]
  public init(stringLiteral value: String) { key = value; arguments = [] }
  public init(stringInterpolation: StringInterpolation) {
    key = stringInterpolation.key; arguments = stringInterpolation.arguments
  }
  public struct StringInterpolation: StringInterpolationProtocol {
    var key = ""
    var arguments: [String] = []
    public init(literalCapacity: Int, interpolationCount: Int) {
      key.reserveCapacity(literalCapacity); arguments.reserveCapacity(interpolationCount)
    }
    public mutating func appendLiteral(_ value: String) { key += value }
    public mutating func appendInterpolation<T>(_ value: T) {
      key += "%@"; arguments.append(String(describing: value))
    }
  }
}
