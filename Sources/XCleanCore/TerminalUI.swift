import Foundation

public struct TerminalUI {
    let language: AppLanguage
    private let inputReader: () -> String?
    private let outputWriter: (String) -> Void
    private let exitHandler: (Int32) -> Void

    public init(
        language: AppLanguage = .current,
        inputReader: @escaping () -> String? = { readLine() },
        outputWriter: @escaping (String) -> Void = { Swift.print($0) },
        exitHandler: @escaping (Int32) -> Void = { Foundation.exit($0) }
    ) {
        self.language = language
        self.inputReader = inputReader
        self.outputWriter = outputWriter
        self.exitHandler = exitHandler
    }

    struct TierSummary {
        let tier: CleanupTier
        let items: [ScannedItem]

        var totalSizeBytes: Int64 {
            items.reduce(0) { $0 + ($1.sizeBytes ?? 0) }
        }

        var actionableCount: Int {
            items.filter(\.isActionable).count
        }
    }

    public func printReport(_ report: ScanReport) {
        print(renderTierMenu(report: report))

        let summaries = tierSummaries(report: report)
        if !summaries.isEmpty {
            print("")
        }

        for (index, summary) in summaries.enumerated() {
            if index > 0 {
                print("")
            }
            print(renderTierDetail(summary))
        }
    }

    public func runInteractiveClean(reportProvider: () -> ScanReport, cleaner: Cleaner) {
        while true {
            let report = reportProvider()
            let summaries = tierSummaries(report: report)
            print(renderTierMenu(report: report))
            guard let input = prompt(promptSelectTier()) else {
                return
            }

            if input == "q" {
                return
            }

            guard let index = Int(input), summaries.indices.contains(index - 1) else {
                print(invalidSelectionText())
                print("")
                continue
            }

            handleTier(summaries[index - 1].tier, reportProvider: reportProvider, cleaner: cleaner)
        }
    }

    func tierSummaries(report: ScanReport) -> [TierSummary] {
        let allItems = report.categories.flatMap(\.items)
        let tiers: [CleanupTier] = [.safe, .cleanIfNeeded, .careful]

        return tiers.compactMap { tier in
            let items = allItems.filter { $0.rule.tier == tier }
            guard !items.isEmpty else {
                return nil
            }
            return TierSummary(tier: tier, items: items)
        }
    }

    func renderTierMenu(report: ScanReport) -> String {
        var lines = [menuTitle(), ""]

        for (index, summary) in tierSummaries(report: report).enumerated() {
            lines.append(
                "\(index + 1). \(Localization.tierTitle(summary.tier, language: language))  \(ByteFormatter.string(for: summary.totalSizeBytes))  \(summary.actionableCount) \(itemCountLabel(summary.actionableCount))"
            )
            lines.append("   \(Localization.tierDescription(summary.tier, language: language))")
        }

        return lines.joined(separator: "\n")
    }

    func renderTierDetail(_ summary: TierSummary) -> String {
        var lines = [
            "[\(Localization.tierTitle(summary.tier, language: language))]",
            Localization.tierDescription(summary.tier, language: language),
            labeledValue(totalLabel(), ByteFormatter.string(for: summary.totalSizeBytes)),
            ""
        ]

        for (index, item) in summary.items.enumerated() {
            let copy = item.rule.localizedDecisionCopy(language: language)
            lines.append("\(index + 1). \(item.rule.title)")
            lines.append("   \(labeledValue(sizeLabel(), ByteFormatter.string(for: item.sizeBytes)))")
            lines.append("   \(labeledValue(statusLabel(), localizedScanStatus(item.status)))")
            lines.append("   \(labeledValue(whatItIsLabel(), copy.whatItIs))")
            lines.append("   \(labeledValue(afterDeletionLabel(), copy.afterDeletion))")
            lines.append("   \(labeledValue(whenToCleanLabel(), copy.whenToClean))")

            switch item.rule.kind {
            case .directory:
                if let path = item.rule.path {
                    lines.append("   \(labeledValue(pathLabel(), path))")
                }
            case .command:
                lines.append("   \(labeledValue(commandLabel(), commandDescription(for: item.rule)))")
            }

            if let detail = item.detail {
                lines.append("   \(labeledValue(detailLabel(), detail))")
            }

            lines.append("")
        }

        if lines.last?.isEmpty == true {
            lines.removeLast()
        }

        return lines.joined(separator: "\n")
    }

    func renderDeletionConfirmation(for items: [ScannedItem]) -> String {
        let totalBytes = items.reduce(Int64(0)) { $0 + ($1.sizeBytes ?? 0) }
        var lines = [confirmationTitle()]

        for item in items {
            let copy = item.rule.localizedDecisionCopy(language: language)
            lines.append("- \(item.rule.title)  \(ByteFormatter.string(for: item.sizeBytes))")
            lines.append("  \(labeledValue(afterDeletionLabel(), copy.afterDeletion))")

            switch item.rule.kind {
            case .directory:
                if let path = item.rule.path {
                    lines.append("  \(labeledValue(pathLabel(), path))")
                }
            case .command:
                lines.append("  \(labeledValue(commandLabel(), commandDescription(for: item.rule)))")
            }
        }

        lines.append(labeledValue(totalLabel(), ByteFormatter.string(for: totalBytes)))
        return lines.joined(separator: "\n")
    }

    func renderResults(_ results: [DeleteResult]) -> String {
        var lines = [resultsTitle()]

        for result in results {
            let suffix = result.message.map { " (\($0))" } ?? ""
            lines.append("- \(result.item.rule.title): \(localizedDeleteStatus(result.status))\(suffix)")
        }

        return lines.joined(separator: "\n")
    }

    private func handleTier(_ tier: CleanupTier, reportProvider: () -> ScanReport, cleaner: Cleaner) {
        while true {
            let report = reportProvider()
            guard let summary = tierSummary(for: tier, report: report) else {
                return
            }

            print(renderTierDetail(summary))
            print("")
            print(commandsText())

            guard let input = prompt(promptSelectItems()) else {
                return
            }

            if input == "b" {
                return
            }
            if input == "q" {
                exitHandler(0)
                return
            }

            let selectedItems: [ScannedItem]
            if input == "a" {
                selectedItems = summary.items.filter(\.isActionable)
            } else {
                let indexes = input.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                selectedItems = indexes.compactMap { index in
                    guard summary.items.indices.contains(index - 1) else {
                        return nil
                    }
                    return summary.items[index - 1]
                }
            }

            let actionableItems = selectedItems.filter(\.isActionable)
            guard !actionableItems.isEmpty else {
                print(noActionableItemsText())
                print("")
                continue
            }

            if confirmDeletion(for: actionableItems) {
                let results = cleaner.delete(items: actionableItems)
                print("")
                print(renderResults(results))
                print("")
            } else {
                print(cancelledText())
                print("")
            }
        }
    }

    private func confirmDeletion(for items: [ScannedItem]) -> Bool {
        print("")
        print(renderDeletionConfirmation(for: items))
        print("")
        return prompt(confirmPrompt()) == "yes"
    }

    private func prompt(_ message: String) -> String? {
        outputWriter("\(message): ")
        return inputReader()?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tierSummary(for tier: CleanupTier, report: ScanReport) -> TierSummary? {
        tierSummaries(report: report).first(where: { $0.tier == tier })
    }

    private func menuTitle() -> String {
        switch language {
        case .english:
            return "Xcode Cleanup"
        case .simplifiedChinese:
            return "Xcode 清理"
        }
    }

    private func localizedScanStatus(_ status: ScanStatus) -> String {
        switch (status, language) {
        case (.available, .english):
            return "available"
        case (.available, .simplifiedChinese):
            return "可清理"
        case (.missing, .english):
            return "missing"
        case (.missing, .simplifiedChinese):
            return "不存在"
        case (.unsafe, .english):
            return "unsafe"
        case (.unsafe, .simplifiedChinese):
            return "不安全"
        case (.unavailable, .english):
            return "unavailable"
        case (.unavailable, .simplifiedChinese):
            return "不可用"
        }
    }

    private func localizedDeleteStatus(_ status: DeleteStatus) -> String {
        switch (status, language) {
        case (.deleted, .english):
            return "deleted"
        case (.deleted, .simplifiedChinese):
            return "已删除"
        case (.skipped, .english):
            return "skipped"
        case (.skipped, .simplifiedChinese):
            return "已跳过"
        case (.failed, .english):
            return "failed"
        case (.failed, .simplifiedChinese):
            return "失败"
        }
    }

    private func promptSelectTier() -> String {
        switch language {
        case .english:
            return "Select cleanup tier number, or q to quit"
        case .simplifiedChinese:
            return "选择清理层级编号，或输入 q 退出"
        }
    }

    private func invalidSelectionText() -> String {
        switch language {
        case .english:
            return "Invalid selection."
        case .simplifiedChinese:
            return "选择无效。"
        }
    }

    private func commandsText() -> String {
        switch language {
        case .english:
            return "Commands: number(s), a = all actionable, b = back, q = quit"
        case .simplifiedChinese:
            return "命令：输入编号，a = 全选可清理项，b = 返回，q = 退出"
        }
    }

    private func promptSelectItems() -> String {
        switch language {
        case .english:
            return "Select item(s)"
        case .simplifiedChinese:
            return "选择要清理的项目"
        }
    }

    private func noActionableItemsText() -> String {
        switch language {
        case .english:
            return "No actionable items selected."
        case .simplifiedChinese:
            return "没有选中可清理项目。"
        }
    }

    private func cancelledText() -> String {
        switch language {
        case .english:
            return "Cancelled."
        case .simplifiedChinese:
            return "已取消。"
        }
    }

    private func confirmationTitle() -> String {
        switch language {
        case .english:
            return "Confirm deleting these items:"
        case .simplifiedChinese:
            return "确认删除以下项目："
        }
    }

    private func confirmPrompt() -> String {
        switch language {
        case .english:
            return "Type yes to confirm"
        case .simplifiedChinese:
            return "输入 yes 确认"
        }
    }

    private func resultsTitle() -> String {
        switch language {
        case .english:
            return "Results"
        case .simplifiedChinese:
            return "结果"
        }
    }

    private func totalLabel() -> String {
        switch language {
        case .english:
            return "total"
        case .simplifiedChinese:
            return "总计"
        }
    }

    private func itemCountLabel(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "item" : "items"
        case .simplifiedChinese:
            return "项"
        }
    }

    private func sizeLabel() -> String {
        switch language {
        case .english:
            return "size"
        case .simplifiedChinese:
            return "大小"
        }
    }

    private func statusLabel() -> String {
        switch language {
        case .english:
            return "status"
        case .simplifiedChinese:
            return "状态"
        }
    }

    private func whatItIsLabel() -> String {
        switch language {
        case .english:
            return "what it is"
        case .simplifiedChinese:
            return "这是什么"
        }
    }

    private func afterDeletionLabel() -> String {
        switch language {
        case .english:
            return "after deletion"
        case .simplifiedChinese:
            return "删除后影响"
        }
    }

    private func whenToCleanLabel() -> String {
        switch language {
        case .english:
            return "when to clean"
        case .simplifiedChinese:
            return "适合什么时候清理"
        }
    }

    private func pathLabel() -> String {
        switch language {
        case .english:
            return "path"
        case .simplifiedChinese:
            return "路径"
        }
    }

    private func commandLabel() -> String {
        switch language {
        case .english:
            return "command"
        case .simplifiedChinese:
            return "命令"
        }
    }

    private func detailLabel() -> String {
        switch language {
        case .english:
            return "detail"
        case .simplifiedChinese:
            return "详情"
        }
    }

    private func commandDescription(for rule: CleanupRule) -> String {
        switch rule.identifier {
        case "simctl-unavailable":
            return "xcrun simctl delete unavailable"
        default:
            return rule.path ?? rule.title
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> String {
        "\(label)\(labelSeparator())\(labelSpacing())\(value)"
    }

    private func labelSeparator() -> String {
        switch language {
        case .english:
            return ":"
        case .simplifiedChinese:
            return "："
        }
    }

    private func labelSpacing() -> String {
        switch language {
        case .english:
            return " "
        case .simplifiedChinese:
            return ""
        }
    }

    private func print(_ text: String) {
        outputWriter(text)
    }
}
