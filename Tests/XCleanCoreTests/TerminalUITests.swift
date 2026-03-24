import XCTest
@testable import XCleanCore

final class TerminalUITests: XCTestCase {
    func testTierSummariesGroupItemsByCleanupTier() {
        let ui = TerminalUI(language: .english)
        let report = makeReport()

        let summaries = ui.tierSummaries(report: report)

        XCTAssertEqual(summaries.map(\.tier), [.safe, .cleanIfNeeded, .careful])
        XCTAssertEqual(summaries.map(\.actionableCount), [3, 5, 1])
    }

    func testRenderTierMenuUsesLocalizedTierNamesAndDescriptions() {
        let ui = TerminalUI(language: .simplifiedChinese)
        let report = makeReport()

        let output = ui.renderTierMenu(report: report)

        XCTAssertTrue(output.contains("Xcode 清理"))
        XCTAssertTrue(output.contains("1. 安全清理"))
        XCTAssertTrue(output.contains("优先删除。这些项目需要时会自动重建。"))
        XCTAssertTrue(output.contains("2. 按需清理"))
        XCTAssertTrue(output.contains("3. 谨慎清理"))
    }

    func testRenderTierDetailsShowsLocalizedDecisionCopyAndLocation() {
        let ui = TerminalUI(language: .english)
        let report = makeReport()
        let summary = ui.tierSummaries(report: report)[0]

        let output = ui.renderTierDetail(summary)

        XCTAssertTrue(output.contains("[Safe Cleanup]"))
        XCTAssertTrue(output.contains("DerivedData"))
        XCTAssertTrue(output.contains("what it is: Xcode-generated build output and indexes."))
        XCTAssertTrue(output.contains("after deletion: The cache is recreated the next time Xcode builds the project."))
        XCTAssertTrue(output.contains("when to clean: Use it when DerivedData is large, stale, or causing build issues."))
        XCTAssertTrue(output.contains("path: /tmp/example-home/Library/Developer/Xcode/DerivedData"))
        XCTAssertTrue(output.contains("command: xcrun simctl delete unavailable"))
    }

    func testRenderDeletionConfirmationIsLocalizedAndImpactOriented() {
        let ui = TerminalUI(language: .simplifiedChinese)
        let rules = CleanupRule.defaultRules(homeDirectory: URL(fileURLWithPath: "/tmp/example-home", isDirectory: true))
        let derivedData = makeItem(ruleID: "derived-data", rules: rules, sizeBytes: 100)
        let simulatorDevices = makeItem(ruleID: "simulator-devices", rules: rules, sizeBytes: 200)

        let output = ui.renderDeletionConfirmation(for: [derivedData, simulatorDevices])

        XCTAssertTrue(output.contains("确认删除以下项目："))
        XCTAssertTrue(output.contains("删除后影响：下次 Xcode 编译项目时会重新创建这些缓存。"))
        XCTAssertTrue(output.contains("删除后影响：模拟器设备可能会被重置，本地测试数据也可能丢失。"))
        XCTAssertFalse(output.contains("输入 yes 确认"))
    }

    func testRenderTierDetailsKeepsSimulatorDevicesCollapsedUntilSelectionStep() {
        let ui = TerminalUI(language: .english)
        let summary = simulatorDeviceSummary()

        let output = ui.renderTierDetail(summary)

        XCTAssertFalse(output.contains("iPhone 15"))
        XCTAssertFalse(output.contains("iPhone 16"))
        XCTAssertFalse(output.contains("system version: iOS 17.4"))
        XCTAssertFalse(output.contains("recommended to keep"))
        XCTAssertFalse(output.contains("模拟器设备"))
        XCTAssertFalse(output.contains("keep one common simulator"))
    }

    func testRenderDeletionConfirmationWarnsToKeepOneCommonSimulator() {
        let ui = TerminalUI(language: .english)
        let item = simulatorDeviceItem()

        let output = ui.renderDeletionConfirmation(for: [item])

        XCTAssertTrue(output.contains("iPhone 15"))
        XCTAssertTrue(output.contains("iPhone 16"))
        XCTAssertTrue(output.contains("keep one common simulator"))
        XCTAssertTrue(output.contains("Simulator devices may be reset and local test data can be lost."))
        XCTAssertFalse(output.contains("- CoreSimulator/Devices"))
    }

    func testRenderTierDetailsLocalizesStatusLabels() {
        let ui = TerminalUI(language: .simplifiedChinese)
        let report = makeReport()
        let summary = ui.tierSummaries(report: report)[0]

        let output = ui.renderTierDetail(summary)

        XCTAssertTrue(output.contains("状态：可清理"))
    }

    func testRenderResultsLocalizesDeleteStatuses() {
        let ui = TerminalUI(language: .simplifiedChinese)
        let rules = CleanupRule.defaultRules(homeDirectory: URL(fileURLWithPath: "/tmp/example-home", isDirectory: true))
        let item = makeItem(ruleID: "derived-data", rules: rules, sizeBytes: 100)
        let results = [
            DeleteResult(item: item, status: .deleted, message: nil),
            DeleteResult(item: item, status: .failed, message: "permission denied")
        ]

        let output = ui.renderResults(results)

        XCTAssertTrue(output.contains("结果"))
        XCTAssertTrue(output.contains("DerivedData: 已删除"))
        XCTAssertTrue(output.contains("DerivedData: 失败 (permission denied)"))
    }

    func testRenderResultsExpandsSimulatorDeviceSelections() {
        let ui = TerminalUI(language: .english)
        let item = simulatorDeviceItem()
        let results = [
            DeleteResult(item: item, status: .deleted, message: nil)
        ]

        let output = ui.renderResults(results)

        XCTAssertTrue(output.contains("iPhone 15"))
        XCTAssertTrue(output.contains("iPhone 16"))
        XCTAssertTrue(output.contains("selected device"))
        XCTAssertFalse(output.contains("- CoreSimulator/Devices"))
    }

    func testInteractiveCleanRefreshesTierDetailsAfterDeletion() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let derivedData = root.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 32).write(to: derivedData.appendingPathComponent("a.bin"))

        let rules = [
            CleanupRule(
                identifier: "derived-data",
                title: "DerivedData",
                category: .buildArtifacts,
                kind: .directory,
                path: derivedData.path,
                description: "Build products",
                recommendation: .recommended,
                tier: .safe
            )
        ]

        let validator = PathSafetyValidator(homeDirectory: root, allowedPaths: rules.compactMap(\.path))
        let scanner = Scanner(
            fileManager: .default,
            pathSafetyValidator: validator,
            processRunner: MockProcessRunner()
        )
        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: validator,
            processRunner: MockProcessRunner()
        )

        var inputs = Array(["1", "1", "yes", "b"])
        var outputs = [String]()
        let ui = TerminalUI(
            language: .english,
            inputReader: { inputs.isEmpty ? nil : inputs.removeFirst() },
            outputWriter: { outputs.append($0) },
            exitHandler: { _ in XCTFail("Unexpected exit") }
        )

        ui.runInteractiveClean(
            reportProvider: { scanner.scan(rules: rules) },
            cleaner: cleaner
        )

        let output = outputs.joined(separator: "\n")
        XCTAssertTrue(output.contains("1. Safe Cleanup"))
        XCTAssertTrue(output.contains("1 item"))
        XCTAssertTrue(output.contains("Results"))
        XCTAssertTrue(output.contains("DerivedData: deleted"))
        XCTAssertTrue(output.contains("status: missing"))
        XCTAssertTrue(output.contains("detail: Path does not exist."))
        XCTAssertTrue(output.contains("0 items"))
    }

    func testInteractiveCleanSupportsSimulatorCandidateSelectionAndQuit() {
        let item = simulatorDeviceItem()
        let report = ScanReport(categories: [
            CategorySummary(category: .simulators, items: [item])
        ])

        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: URL(fileURLWithPath: "/tmp/example-home", isDirectory: true),
                allowedPaths: [item.rule.path!]
            ),
            processRunner: MockProcessRunner()
        )

        var inputs = ["1", "1", "q"]
        var outputs = [String]()
        var exitCode: Int32?
        let ui = TerminalUI(
            language: .english,
            inputReader: { inputs.isEmpty ? nil : inputs.removeFirst() },
            outputWriter: { outputs.append($0) },
            exitHandler: { code in exitCode = code }
        )

        ui.runInteractiveClean(reportProvider: { report }, cleaner: cleaner)

        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(outputs.joined(separator: "\n").contains("Select simulator devices to delete"))
    }

    func testInteractiveCleanRetriesAfterInvalidSimulatorCandidateSelection() {
        let item = simulatorDeviceItem()
        let report = ScanReport(categories: [
            CategorySummary(category: .simulators, items: [item])
        ])

        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: URL(fileURLWithPath: "/tmp/example-home", isDirectory: true),
                allowedPaths: [item.rule.path!]
            ),
            processRunner: MockProcessRunner()
        )

        var inputs = ["1", "1", "9", "1", "yes", "b"]
        var outputs = [String]()
        let ui = TerminalUI(
            language: .english,
            inputReader: { inputs.isEmpty ? nil : inputs.removeFirst() },
            outputWriter: { outputs.append($0) },
            exitHandler: { _ in XCTFail("Unexpected exit") }
        )

        ui.runInteractiveClean(reportProvider: { report }, cleaner: cleaner)

        let output = outputs.joined(separator: "\n")
        XCTAssertTrue(output.contains("Invalid selection."))
        XCTAssertTrue(output.contains("iPhone 15"))
        XCTAssertTrue(output.contains("Results"))
    }

    private func makeReport() -> ScanReport {
        let home = URL(fileURLWithPath: "/tmp/example-home", isDirectory: true)
        let rules = CleanupRule.defaultRules(homeDirectory: home)
        let sizes: [String: Int64] = [
            "derived-data": 100,
            "previews": 200,
            "simctl-unavailable": 50,
            "documentation-cache": 75,
            "ios-device-support": 125,
            "tvos-device-support": 100,
            "xcode-logs": 80,
            "coresimulator-logs": 60,
            "simulator-devices": 300
        ]

        let grouped = Dictionary(grouping: rules.map { rule in
            ScannedItem(
                rule: rule,
                status: .available,
                sizeBytes: sizes[rule.identifier] ?? 0,
                detail: nil
            )
        }, by: { $0.rule.category })

        return ScanReport(
            categories: RuleCategory.allCases.compactMap { category in
                guard let items = grouped[category] else {
                    return nil
                }
                return CategorySummary(category: category, items: items)
            }
        )
    }

    private func makeItem(ruleID: String, rules: [CleanupRule], sizeBytes: Int64) -> ScannedItem {
        let rule = try! XCTUnwrap(rules.first(where: { $0.identifier == ruleID }))
        return ScannedItem(rule: rule, status: .available, sizeBytes: sizeBytes, detail: nil)
    }

    private func simulatorDeviceSummary() -> TerminalUI.TierSummary {
        let item = simulatorDeviceItem()
        return TerminalUI.TierSummary(tier: .careful, items: [item])
    }

    private func simulatorDeviceItem() -> ScannedItem {
        let home = URL(fileURLWithPath: "/tmp/example-home", isDirectory: true)
        let rule = CleanupRule(
            identifier: "simulator-devices",
            title: "CoreSimulator/Devices",
            category: .simulators,
            kind: .directory,
            path: home.appendingPathComponent("Library/Developer/CoreSimulator/Devices").path,
            description: "Simulator device data",
            recommendation: .caution,
            tier: .careful
        )
        return ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: 256,
            detail: "2 simulator device(s). Skipped 1 unmapped directory.",
            candidates: [
                CleanupCandidate(
                    identifier: "11111111-2222-3333-4444-555555555555",
                    title: "iPhone 15",
                    path: home.appendingPathComponent("Library/Developer/CoreSimulator/Devices/11111111-2222-3333-4444-555555555555").path,
                    sizeBytes: 128,
                    detail: "iOS 17.4",
                    isRecommendedToKeep: true
                ),
                CleanupCandidate(
                    identifier: "22222222-3333-4444-5555-666666666666",
                    title: "iPhone 16",
                    path: home.appendingPathComponent("Library/Developer/CoreSimulator/Devices/22222222-3333-4444-5555-666666666666").path,
                    sizeBytes: 128,
                    detail: "iOS 18.0",
                    isRecommendedToKeep: false
                )
            ]
        )
    }
}
