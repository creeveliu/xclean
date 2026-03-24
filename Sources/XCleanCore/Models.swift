import Foundation

public enum RuleCategory: String, CaseIterable, Sendable {
    case buildArtifacts
    case deviceSupport
    case simulators
    case previewsAndDocs
    case logs

    public var title: String {
        switch self {
        case .buildArtifacts:
            return "Build Artifacts"
        case .deviceSupport:
            return "Device Support"
        case .simulators:
            return "Simulators"
        case .previewsAndDocs:
            return "Previews & Docs"
        case .logs:
            return "Logs"
        }
    }
}

public enum RuleKind: Sendable {
    case directory
    case command
}

public enum CleanupTier: String, Sendable {
    case safe
    case cleanIfNeeded
    case careful
}

public enum CleanupRecommendation: String, Sendable {
    case recommended
    case optional
    case caution

    public var label: String {
        rawValue
    }
}

public struct CleanupRule: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let category: RuleCategory
    public let kind: RuleKind
    public let path: String?
    public let description: String
    public let recommendation: CleanupRecommendation
    public let tier: CleanupTier

    public init(
        identifier: String,
        title: String,
        category: RuleCategory,
        kind: RuleKind,
        path: String?,
        description: String,
        recommendation: CleanupRecommendation,
        tier: CleanupTier = .safe
    ) {
        self.identifier = identifier
        self.title = title
        self.category = category
        self.kind = kind
        self.path = path
        self.description = description
        self.recommendation = recommendation
        self.tier = tier
    }

    public static func defaultRules(homeDirectory: URL) -> [CleanupRule] {
        let root = homeDirectory.standardizedFileURL.path

        func homePath(_ suffix: String) -> String {
            URL(fileURLWithPath: root, isDirectory: true)
                .appendingPathComponent(suffix, isDirectory: true)
                .standardizedFileURL.path
        }

        return [
            CleanupRule(
                identifier: "derived-data",
                title: "DerivedData",
                category: .buildArtifacts,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/DerivedData"),
                description: "Xcode build products and indexes.",
                recommendation: .recommended,
                tier: .safe
            ),
            CleanupRule(
                identifier: "documentation-cache",
                title: "DocumentationCache",
                category: .previewsAndDocs,
                kind: .directory,
                path: homePath("Library/Developer/Shared/Documentation/DocumentationCache"),
                description: "Cached developer documentation.",
                recommendation: .optional,
                tier: .cleanIfNeeded
            ),
            CleanupRule(
                identifier: "previews",
                title: "UserData/Previews",
                category: .previewsAndDocs,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/UserData/Previews"),
                description: "SwiftUI preview build data.",
                recommendation: .recommended,
                tier: .safe
            ),
            CleanupRule(
                identifier: "ios-device-support",
                title: "iOS DeviceSupport",
                category: .deviceSupport,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/iOS DeviceSupport"),
                description: "Cached symbols for connected iOS devices.",
                recommendation: .optional,
                tier: .cleanIfNeeded
            ),
            CleanupRule(
                identifier: "tvos-device-support",
                title: "tvOS DeviceSupport",
                category: .deviceSupport,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/tvOS DeviceSupport"),
                description: "Cached symbols for connected tvOS devices.",
                recommendation: .optional,
                tier: .cleanIfNeeded
            ),
            CleanupRule(
                identifier: "simulator-devices",
                title: "CoreSimulator/Devices",
                category: .simulators,
                kind: .directory,
                path: homePath("Library/Developer/CoreSimulator/Devices"),
                description: "Simulator device data, app sandboxes, and runtimes.",
                recommendation: .caution,
                tier: .careful
            ),
            CleanupRule(
                identifier: "simctl-unavailable",
                title: "Unavailable Simulators",
                category: .simulators,
                kind: .command,
                path: nil,
                description: "Deletes simulator devices no longer backed by installed runtimes.",
                recommendation: .recommended,
                tier: .safe
            ),
            CleanupRule(
                identifier: "xcode-logs",
                title: "Xcode Logs",
                category: .logs,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/Logs"),
                description: "Xcode log bundles and debug logs.",
                recommendation: .optional,
                tier: .cleanIfNeeded
            ),
            CleanupRule(
                identifier: "coresimulator-logs",
                title: "CoreSimulator Logs",
                category: .logs,
                kind: .directory,
                path: homePath("Library/Logs/CoreSimulator"),
                description: "CoreSimulator log output.",
                recommendation: .optional,
                tier: .cleanIfNeeded
            ),
        ]
    }
}

public struct RuleDecisionCopy: Equatable, Sendable {
    public let whatItIs: String
    public let afterDeletion: String
    public let whenToClean: String

    public init(whatItIs: String, afterDeletion: String, whenToClean: String) {
        self.whatItIs = whatItIs
        self.afterDeletion = afterDeletion
        self.whenToClean = whenToClean
    }
}

public extension CleanupRule {
    func localizedDecisionCopy(language: AppLanguage) -> RuleDecisionCopy {
        switch identifier {
        case "derived-data":
            return ruleCopy(
                language: language,
                englishWhatItIs: "Xcode-generated build output and indexes.",
                chineseWhatItIs: "Xcode 生成的构建输出和索引。",
                englishAfterDeletion: "The cache is recreated the next time Xcode builds the project.",
                chineseAfterDeletion: "下次 Xcode 编译项目时会重新创建这些缓存。",
                englishWhenToClean: "Use it when DerivedData is large, stale, or causing build issues.",
                chineseWhenToClean: "当 DerivedData 占用很大、过期或引发编译问题时再清理。"
            )
        case "documentation-cache":
            return ruleCopy(
                language: language,
                englishWhatItIs: "Cached developer documentation for Xcode.",
                chineseWhatItIs: "Xcode 的开发者文档缓存。",
                englishAfterDeletion: "Xcode will rebuild the cache as you browse documentation again.",
                chineseAfterDeletion: "重新浏览文档时，Xcode 会再次构建缓存。",
                englishWhenToClean: "Use it when you want to reclaim space and do not mind a slower first lookup.",
                chineseWhenToClean: "当你想回收空间，并且不介意首次查阅稍慢时再清理。"
            )
        case "previews":
            return ruleCopy(
                language: language,
                englishWhatItIs: "SwiftUI preview build data.",
                chineseWhatItIs: "SwiftUI 预览的构建数据。",
                englishAfterDeletion: "Previews will rebuild the next time you open a SwiftUI preview.",
                chineseAfterDeletion: "下次打开 SwiftUI 预览时会重新构建。",
                englishWhenToClean: "Use it when previews are stale or you want to free cache space.",
                chineseWhenToClean: "当预览变旧或你想释放缓存空间时再清理。"
            )
        case "ios-device-support":
            return ruleCopy(
                language: language,
                englishWhatItIs: "Cached symbol files for connected iPhone and iPad devices.",
                chineseWhatItIs: "已连接 iPhone 和 iPad 设备的符号缓存文件。",
                englishAfterDeletion: "The files are downloaded again when you connect those devices later.",
                chineseAfterDeletion: "之后再次连接这些设备时会重新下载文件。",
                englishWhenToClean: "Use it when you want to reclaim space and do not need old device symbols.",
                chineseWhenToClean: "当你想回收空间，并且不再需要旧设备符号文件时再清理。"
            )
        case "tvos-device-support":
            return ruleCopy(
                language: language,
                englishWhatItIs: "Cached symbol files for connected Apple TV devices.",
                chineseWhatItIs: "已连接 Apple TV 设备的符号缓存文件。",
                englishAfterDeletion: "The files are downloaded again when you connect those devices later.",
                chineseAfterDeletion: "之后再次连接这些设备时会重新下载文件。",
                englishWhenToClean: "Use it when you want to reclaim space and do not need old device symbols.",
                chineseWhenToClean: "当你想回收空间，并且不再需要旧设备符号文件时再清理。"
            )
        case "simulator-devices":
            return ruleCopy(
                language: language,
                englishWhatItIs: "Simulator device data, app sandboxes, and installed runtimes.",
                chineseWhatItIs: "模拟器设备数据、App 沙盒和已安装运行时。",
                englishAfterDeletion: "Simulator devices may be reset and local test data can be lost.",
                chineseAfterDeletion: "模拟器设备可能会被重置，本地测试数据也可能丢失。",
                englishWhenToClean: "Use it when you no longer need those simulator environments.",
                chineseWhenToClean: "当你不再需要这些模拟器环境时再清理。"
            )
        case "simctl-unavailable":
            return ruleCopy(
                language: language,
                englishWhatItIs: "Simulator entries that no longer match installed runtimes.",
                chineseWhatItIs: "已不再匹配当前运行时的模拟器条目。",
                englishAfterDeletion: "Xcode removes the unavailable simulator entries and keeps usable ones.",
                chineseAfterDeletion: "Xcode 会移除不可用的模拟器条目，并保留仍可使用的条目。",
                englishWhenToClean: "Use it when Simulator lists old devices you no longer need.",
                chineseWhenToClean: "当 Simulator 里出现你不再需要的旧设备时再清理。"
            )
        case "xcode-logs":
            return ruleCopy(
                language: language,
                englishWhatItIs: "Xcode log bundles and debug logs.",
                chineseWhatItIs: "Xcode 的日志包和调试日志。",
                englishAfterDeletion: "New logs will be created the next time Xcode writes them.",
                chineseAfterDeletion: "下次 Xcode 记录日志时会重新创建新的日志。",
                englishWhenToClean: "Use it when logs are growing or you no longer need old troubleshooting data.",
                chineseWhenToClean: "当日志占用变大，或者你不再需要旧排查数据时再清理。"
            )
        case "coresimulator-logs":
            return ruleCopy(
                language: language,
                englishWhatItIs: "CoreSimulator log output.",
                chineseWhatItIs: "CoreSimulator 的日志输出。",
                englishAfterDeletion: "New logs will be created the next time the Simulator runs.",
                chineseAfterDeletion: "下次模拟器运行时会重新创建新的日志。",
                englishWhenToClean: "Use it when you want to reclaim space and do not need old simulator logs.",
                chineseWhenToClean: "当你想回收空间，并且不再需要旧模拟器日志时再清理。"
            )
        default:
            return ruleCopy(
                language: language,
                englishWhatItIs: description,
                chineseWhatItIs: description,
                englishAfterDeletion: "The item will be recreated if Xcode needs it again.",
                chineseAfterDeletion: "如果 Xcode 之后还需要它，就会重新创建。",
                englishWhenToClean: recommendation == .caution
                    ? "Use it only if you understand the impact on your local setup."
                    : "Use it when you want to reclaim space.",
                chineseWhenToClean: recommendation == .caution
                    ? "只有在你了解它会如何影响本地环境时再清理。"
                    : "当你想回收空间时再清理。"
            )
        }
    }

    private func ruleCopy(
        language: AppLanguage,
        englishWhatItIs: String,
        chineseWhatItIs: String,
        englishAfterDeletion: String,
        chineseAfterDeletion: String,
        englishWhenToClean: String,
        chineseWhenToClean: String
    ) -> RuleDecisionCopy {
        switch language {
        case .english:
            return RuleDecisionCopy(
                whatItIs: englishWhatItIs,
                afterDeletion: englishAfterDeletion,
                whenToClean: englishWhenToClean
            )
        case .simplifiedChinese:
            return RuleDecisionCopy(
                whatItIs: chineseWhatItIs,
                afterDeletion: chineseAfterDeletion,
                whenToClean: chineseWhenToClean
            )
        }
    }
}

public enum ScanStatus: String, Sendable {
    case available
    case missing
    case unsafe
    case unavailable
}

public struct ScannedItem: Sendable {
    public let rule: CleanupRule
    public let status: ScanStatus
    public let sizeBytes: Int64?
    public let detail: String?

    public init(rule: CleanupRule, status: ScanStatus, sizeBytes: Int64?, detail: String?) {
        self.rule = rule
        self.status = status
        self.sizeBytes = sizeBytes
        self.detail = detail
    }

    public var isActionable: Bool {
        status == .available
    }
}

public struct CategorySummary: Sendable {
    public let category: RuleCategory
    public let items: [ScannedItem]

    public var totalSizeBytes: Int64 {
        items.reduce(0) { $0 + ($1.sizeBytes ?? 0) }
    }

    public var actionableCount: Int {
        items.filter(\.isActionable).count
    }
}

public struct ScanReport: Sendable {
    public let categories: [CategorySummary]

    public var totalSizeBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalSizeBytes }
    }
}

public enum DeleteStatus: String, Sendable {
    case deleted
    case skipped
    case failed
}

public struct DeleteResult: Sendable {
    public let item: ScannedItem
    public let status: DeleteStatus
    public let message: String?
}
