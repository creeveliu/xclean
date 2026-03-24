import XCTest
@testable import XCleanCore

final class LocalizationTests: XCTestCase {
    func testLanguageResolutionMapsChineseIdentifiersToSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.resolve(from: ["zh-Hans"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(from: ["zh-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(from: ["zh"]), .simplifiedChinese)
    }

    func testLanguageResolutionFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.resolve(from: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.resolve(from: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.resolve(from: []), .english)
    }

    func testTierTitlesAndDescriptionsAreLocalized() {
        XCTAssertEqual(Localization.tierTitle(.safe, language: .english), "Safe Cleanup")
        XCTAssertEqual(Localization.tierTitle(.safe, language: .simplifiedChinese), "安全清理")

        XCTAssertEqual(Localization.tierDescription(.careful, language: .english), "Can be cleaned, but may remove simulator environments or local test data.")
        XCTAssertEqual(Localization.tierDescription(.careful, language: .simplifiedChinese), "可以清理，但可能移除模拟器环境或本地测试数据。")
    }
}
