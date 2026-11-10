import XCTest
@testable import QuickAuthCore

final class LocalizationTests: XCTestCase {
  func testLanguageSelectionAndFallback() {
    XCTAssertEqual(L10n.resolved(preference: "system", preferredLanguages: ["zh-TW"]), "zh-Hans")
    XCTAssertEqual(L10n.resolved(preference: "system", preferredLanguages: ["de-DE", "zh-Hans"]), "en")
    XCTAssertEqual(L10n.resolved(preference: "en", preferredLanguages: ["zh-Hans"]), "en")
    XCTAssertEqual(L10n.resolved(preference: "zh-Hans", preferredLanguages: ["en"]), "zh-Hans")
  }
  func testInterpolationPreservesAccountNamesAndPercentSigns() {
    let text: LocalizedText = "复制 \("账户 %@ 100%") 的验证码"
    XCTAssertEqual(L10n.render(text, language: "en"), "Copy code for 账户 %@ 100%")
    XCTAssertEqual(L10n.render(text, language: "zh-Hans"), "复制 账户 %@ 100% 的验证码")
    XCTAssertEqual(L10n.render("新增 \(3) · 重复 \(2)", language: "en"), "3 new · 2 duplicates")
  }
  func testTranslationPlaceholdersMatch() {
    for (key, value) in L10n.english {
      XCTAssertEqual(key.components(separatedBy: "%@").count, value.components(separatedBy: "%@").count, key)
      XCTAssertFalse(value.isEmpty, key)
    }
  }
}
