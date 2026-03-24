import Foundation

public enum AppLanguage: Equatable, Sendable {
    case english
    case simplifiedChinese

    public static func resolve(from preferredIdentifiers: [String]) -> AppLanguage {
        for identifier in preferredIdentifiers {
            let normalized = identifier.lowercased()
            if normalized == "zh" || normalized.hasPrefix("zh-") {
                return .simplifiedChinese
            }
        }
        return .english
    }

    public static var current: AppLanguage {
        resolve(from: Locale.preferredLanguages)
    }
}

public enum Localization {
    public static func tierTitle(_ tier: CleanupTier, language: AppLanguage) -> String {
        switch (tier, language) {
        case (.safe, .english):
            return "Safe Cleanup"
        case (.safe, .simplifiedChinese):
            return "安全清理"
        case (.cleanIfNeeded, .english):
            return "Clean If Needed"
        case (.cleanIfNeeded, .simplifiedChinese):
            return "按需清理"
        case (.careful, .english):
            return "Careful Cleanup"
        case (.careful, .simplifiedChinese):
            return "谨慎清理"
        }
    }

    public static func tierDescription(_ tier: CleanupTier, language: AppLanguage) -> String {
        switch (tier, language) {
        case (.safe, .english):
            return "Delete first. These items are rebuilt automatically when needed."
        case (.safe, .simplifiedChinese):
            return "优先删除。这些项目需要时会自动重建。"
        case (.cleanIfNeeded, .english):
            return "Usually safe to delete, but related tools may need to rebuild or redownload data later."
        case (.cleanIfNeeded, .simplifiedChinese):
            return "通常可以删除，但相关工具之后可能需要重新构建或下载数据。"
        case (.careful, .english):
            return "Can be cleaned, but may remove simulator environments or local test data."
        case (.careful, .simplifiedChinese):
            return "可以清理，但可能移除模拟器环境或本地测试数据。"
        }
    }
}
