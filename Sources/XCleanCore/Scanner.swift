import Foundation

public struct Scanner {
    private let fileManager: FileManager
    private let pathSafetyValidator: PathSafetyValidator
    private let processRunner: ProcessRunning

    public init(
        fileManager: FileManager = .default,
        pathSafetyValidator: PathSafetyValidator,
        processRunner: ProcessRunning = ProcessRunner()
    ) {
        self.fileManager = fileManager
        self.pathSafetyValidator = pathSafetyValidator
        self.processRunner = processRunner
    }

    public func scan(rules: [CleanupRule]) -> ScanReport {
        let items = rules.map(scan(rule:))
        let categories = RuleCategory.allCases.map { category in
            CategorySummary(category: category, items: items.filter { $0.rule.category == category })
        }
        return ScanReport(categories: categories)
    }

    private func scan(rule: CleanupRule) -> ScannedItem {
        switch rule.kind {
        case .directory:
            return scanDirectory(rule: rule)
        case .command:
            return scanUnavailableSimulators(rule: rule)
        }
    }

    private func scanDirectory(rule: CleanupRule) -> ScannedItem {
        guard let path = rule.path else {
            return ScannedItem(rule: rule, status: .unavailable, sizeBytes: nil, detail: "Missing path.")
        }
        guard pathSafetyValidator.isSafe(path: path) else {
            return ScannedItem(rule: rule, status: .unsafe, sizeBytes: nil, detail: "Path rejected by safety rules.")
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ScannedItem(rule: rule, status: .missing, sizeBytes: 0, detail: "Path does not exist.")
        }

        return ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: directorySize(atPath: path),
            detail: nil
        )
    }

    private func scanUnavailableSimulators(rule: CleanupRule) -> ScannedItem {
        let result = processRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "unavailable"]
        )

        guard result.exitCode == 0 else {
            return ScannedItem(
                rule: rule,
                status: .unavailable,
                sizeBytes: nil,
                detail: trimmed(result.standardError).nilIfEmpty ?? "xcrun simctl unavailable."
            )
        }

        let unavailableLines = result.standardOutput
            .split(separator: "\n")
            .map(String.init)
            .filter { line in
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                return !trimmedLine.isEmpty &&
                    trimmedLine != "== Devices ==" &&
                    !trimmedLine.hasPrefix("--")
            }

        guard !unavailableLines.isEmpty else {
            return ScannedItem(
                rule: rule,
                status: .missing,
                sizeBytes: 0,
                detail: "No unavailable simulators."
            )
        }

        return ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: nil,
            detail: "\(unavailableLines.count) unavailable simulator(s)."
        )
    }

    private func directorySize(atPath path: String) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path, isDirectory: true),
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else {
                    continue
                }
                if let fileSize = values.fileSize {
                    total += Int64(fileSize)
                }
            } catch {
                continue
            }
        }
        return total
    }

    private func trimmed(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
