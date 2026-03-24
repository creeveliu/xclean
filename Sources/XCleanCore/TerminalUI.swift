import Foundation

public struct TerminalUI {
    public init() {}

    public func printReport(_ report: ScanReport) {
        print("Xcode Cleanup Scan")
        print("")
        for (index, summary) in report.categories.enumerated() {
            print("\(index + 1). \(summary.category.title)  \(ByteFormatter.string(for: summary.totalSizeBytes))  \(summary.actionableCount) item(s)")
        }
        print("")
        for summary in report.categories {
            printCategory(summary)
            print("")
        }
    }

    public func runInteractiveClean(report: ScanReport, cleaner: Cleaner) {
        while true {
            showCategoryMenu(report: report)
            guard let input = prompt("Select category number, or q to quit") else {
                return
            }

            if input == "q" {
                return
            }

            guard let index = Int(input), report.categories.indices.contains(index - 1) else {
                print("Invalid selection.")
                print("")
                continue
            }

            let summary = report.categories[index - 1]
            handleCategory(summary, cleaner: cleaner)
        }
    }

    private func showCategoryMenu(report: ScanReport) {
        print("Xcode Cleanup")
        print("")
        for (index, summary) in report.categories.enumerated() {
            print("\(index + 1). \(summary.category.title)  \(ByteFormatter.string(for: summary.totalSizeBytes))  \(summary.actionableCount) item(s)")
        }
        print("")
    }

    private func handleCategory(_ summary: CategorySummary, cleaner: Cleaner) {
        while true {
            printCategory(summary)
            print("")
            print("Commands: number(s), a = all actionable, b = back, q = quit")

            guard let input = prompt("Select item(s)") else {
                return
            }

            if input == "b" {
                return
            }
            if input == "q" {
                Foundation.exit(0)
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
                print("No actionable items selected.")
                print("")
                continue
            }

            if confirmDeletion(for: actionableItems) {
                let results = cleaner.delete(items: actionableItems)
                print("")
                printResults(results)
                print("")
            } else {
                print("Cancelled.")
                print("")
            }
        }
    }

    private func confirmDeletion(for items: [ScannedItem]) -> Bool {
        let totalBytes = items.reduce(Int64(0)) { $0 + ($1.sizeBytes ?? 0) }
        print("")
        print("Delete these items:")
        for item in items {
            let location = item.rule.path ?? "xcrun simctl delete unavailable"
            print("- \(item.rule.title)  \(ByteFormatter.string(for: item.sizeBytes))")
            print("  \(location)")
        }
        print("Total: \(ByteFormatter.string(for: totalBytes))")
        print("")
        return prompt("Type yes to confirm") == "yes"
    }

    private func printResults(_ results: [DeleteResult]) {
        print("Results")
        for result in results {
            let suffix = result.message.map { " (\($0))" } ?? ""
            print("- \(result.item.rule.title): \(result.status.rawValue)\(suffix)")
        }
    }

    private func printCategory(_ summary: CategorySummary) {
        print("[\(summary.category.title)]")
        print("Total: \(ByteFormatter.string(for: summary.totalSizeBytes))")
        print("")
        for (index, item) in summary.items.enumerated() {
            let location = item.rule.path ?? "xcrun simctl delete unavailable"
            print("\(index + 1). \(item.rule.title)")
            print("   size: \(ByteFormatter.string(for: item.sizeBytes))")
            print("   status: \(item.status.rawValue)")
            print("   path: \(location)")
            print("   note: \(item.rule.description)")
            print("   recommendation: \(item.rule.recommendation.label)")
            if let detail = item.detail {
                print("   detail: \(detail)")
            }
            print("")
        }
    }

    private func prompt(_ message: String) -> String? {
        print("\(message): ", terminator: "")
        return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
