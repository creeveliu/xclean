import XCTest
@testable import XCleanCore

final class RuleDefinitionTests: XCTestCase {
    func testDefaultRulesContainExpectedXcodeTargets() {
        let home = URL(fileURLWithPath: "/tmp/example-home", isDirectory: true)
        let rules = CleanupRule.defaultRules(homeDirectory: home)

        XCTAssertTrue(rules.contains(where: {
            $0.identifier == "derived-data" &&
            $0.kind == .directory &&
            $0.category == .buildArtifacts &&
            $0.path == home.appendingPathComponent("Library/Developer/Xcode/DerivedData").path
        }))

        XCTAssertTrue(rules.contains(where: {
            $0.identifier == "simctl-unavailable" &&
            $0.kind == .command &&
            $0.category == .simulators
        }))
    }

    func testDefaultRulesAssignExpectedCleanupTiers() {
        let home = URL(fileURLWithPath: "/tmp/example-home", isDirectory: true)
        let rules = CleanupRule.defaultRules(homeDirectory: home)

        XCTAssertEqual(ruleTiers(in: rules, identifiers: [
            "derived-data",
            "previews",
            "simctl-unavailable"
        ]), [.safe, .safe, .safe])

        XCTAssertEqual(ruleTiers(in: rules, identifiers: [
            "documentation-cache",
            "ios-device-support",
            "tvos-device-support",
            "xcode-logs",
            "coresimulator-logs"
        ]), [.cleanIfNeeded, .cleanIfNeeded, .cleanIfNeeded, .cleanIfNeeded, .cleanIfNeeded])

        XCTAssertEqual(ruleTiers(in: rules, identifiers: [
            "simulator-devices"
        ]), [.careful])
    }

    func testDefaultRulesExposeLocalizedDecisionCopy() {
        let home = URL(fileURLWithPath: "/tmp/example-home", isDirectory: true)
        let rules = CleanupRule.defaultRules(homeDirectory: home)

        let derivedData = rules.first(where: { $0.identifier == "derived-data" })
        XCTAssertEqual(
            derivedData?.localizedDecisionCopy(language: .english),
            RuleDecisionCopy(
                whatItIs: "Xcode-generated build output and indexes.",
                afterDeletion: "The cache is recreated the next time Xcode builds the project.",
                whenToClean: "Use it when DerivedData is large, stale, or causing build issues."
            )
        )
        XCTAssertEqual(
            derivedData?.localizedDecisionCopy(language: .simplifiedChinese),
            RuleDecisionCopy(
                whatItIs: "Xcode 生成的构建输出和索引。",
                afterDeletion: "下次 Xcode 编译项目时会重新创建这些缓存。",
                whenToClean: "当 DerivedData 占用很大、过期或引发编译问题时再清理。"
            )
        )

        let simulatorDevices = rules.first(where: { $0.identifier == "simulator-devices" })
        XCTAssertEqual(
            simulatorDevices?.localizedDecisionCopy(language: .english),
            RuleDecisionCopy(
                whatItIs: "Simulator device data, app sandboxes, and installed runtimes.",
                afterDeletion: "Simulator devices may be reset and local test data can be lost.",
                whenToClean: "Use it when you no longer need those simulator environments."
            )
        )
        XCTAssertEqual(
            simulatorDevices?.localizedDecisionCopy(language: .simplifiedChinese),
            RuleDecisionCopy(
                whatItIs: "模拟器设备数据、App 沙盒和已安装运行时。",
                afterDeletion: "模拟器设备可能会被重置，本地测试数据也可能丢失。",
                whenToClean: "当你不再需要这些模拟器环境时再清理。"
            )
        )

        for rule in rules {
            let englishCopy = rule.localizedDecisionCopy(language: .english)
            let chineseCopy = rule.localizedDecisionCopy(language: .simplifiedChinese)

            XCTAssertFalse(englishCopy.whatItIs.isEmpty, "Missing english what-it-is copy for \(rule.identifier)")
            XCTAssertFalse(englishCopy.afterDeletion.isEmpty, "Missing english after-deletion copy for \(rule.identifier)")
            XCTAssertFalse(englishCopy.whenToClean.isEmpty, "Missing english when-to-clean copy for \(rule.identifier)")

            XCTAssertFalse(chineseCopy.whatItIs.isEmpty, "Missing chinese what-it-is copy for \(rule.identifier)")
            XCTAssertFalse(chineseCopy.afterDeletion.isEmpty, "Missing chinese after-deletion copy for \(rule.identifier)")
            XCTAssertFalse(chineseCopy.whenToClean.isEmpty, "Missing chinese when-to-clean copy for \(rule.identifier)")
        }
    }

    private func ruleTiers(in rules: [CleanupRule], identifiers: [String]) -> [CleanupTier] {
        identifiers.compactMap { identifier in
            rules.first(where: { $0.identifier == identifier })?.tier
        }
    }
}
