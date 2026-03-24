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

    public init(
        identifier: String,
        title: String,
        category: RuleCategory,
        kind: RuleKind,
        path: String?,
        description: String,
        recommendation: CleanupRecommendation
    ) {
        self.identifier = identifier
        self.title = title
        self.category = category
        self.kind = kind
        self.path = path
        self.description = description
        self.recommendation = recommendation
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
                recommendation: .recommended
            ),
            CleanupRule(
                identifier: "documentation-cache",
                title: "DocumentationCache",
                category: .previewsAndDocs,
                kind: .directory,
                path: homePath("Library/Developer/Shared/Documentation/DocumentationCache"),
                description: "Cached developer documentation.",
                recommendation: .optional
            ),
            CleanupRule(
                identifier: "previews",
                title: "UserData/Previews",
                category: .previewsAndDocs,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/UserData/Previews"),
                description: "SwiftUI preview build data.",
                recommendation: .recommended
            ),
            CleanupRule(
                identifier: "ios-device-support",
                title: "iOS DeviceSupport",
                category: .deviceSupport,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/iOS DeviceSupport"),
                description: "Cached symbols for connected iOS devices.",
                recommendation: .optional
            ),
            CleanupRule(
                identifier: "tvos-device-support",
                title: "tvOS DeviceSupport",
                category: .deviceSupport,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/tvOS DeviceSupport"),
                description: "Cached symbols for connected tvOS devices.",
                recommendation: .optional
            ),
            CleanupRule(
                identifier: "simulator-devices",
                title: "CoreSimulator/Devices",
                category: .simulators,
                kind: .directory,
                path: homePath("Library/Developer/CoreSimulator/Devices"),
                description: "Simulator device data, app sandboxes, and runtimes.",
                recommendation: .caution
            ),
            CleanupRule(
                identifier: "simctl-unavailable",
                title: "Unavailable Simulators",
                category: .simulators,
                kind: .command,
                path: nil,
                description: "Deletes simulator devices no longer backed by installed runtimes.",
                recommendation: .recommended
            ),
            CleanupRule(
                identifier: "xcode-logs",
                title: "Xcode Logs",
                category: .logs,
                kind: .directory,
                path: homePath("Library/Developer/Xcode/Logs"),
                description: "Xcode log bundles and debug logs.",
                recommendation: .optional
            ),
            CleanupRule(
                identifier: "coresimulator-logs",
                title: "CoreSimulator Logs",
                category: .logs,
                kind: .directory,
                path: homePath("Library/Logs/CoreSimulator"),
                description: "CoreSimulator log output.",
                recommendation: .optional
            ),
        ]
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
