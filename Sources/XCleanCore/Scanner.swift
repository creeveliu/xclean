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
            if rule.identifier == "simulator-devices" {
                return scanSimulatorDevices(rule: rule)
            }
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
            arguments: ["simctl", "list", "devices", "unavailable"],
            environment: nil
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

    private func scanSimulatorDevices(rule: CleanupRule) -> ScannedItem {
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

        let result = processRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "--json"],
            environment: nil
        )

        guard result.exitCode == 0 else {
            return ScannedItem(
                rule: rule,
                status: .unavailable,
                sizeBytes: nil,
                detail: trimmed(result.standardError).nilIfEmpty ?? "xcrun simctl list devices failed."
            )
        }

        let parsedDevicesResult = parseSimulatorDevices(json: result.standardOutput)
        switch parsedDevicesResult {
        case .failure:
            return ScannedItem(
                rule: rule,
                status: .unavailable,
                sizeBytes: nil,
                detail: "Unable to parse simctl device metadata."
            )
        case .success(let parsedDevices):
            return scanSimulatorDeviceDirectories(
                rule: rule,
                rootPath: path,
                parsedDevices: parsedDevices
            )
        }
    }

    private func scanSimulatorDeviceDirectories(
        rule: CleanupRule,
        rootPath: String,
        parsedDevices: [SimulatorDeviceMetadata]
    ) -> ScannedItem {
        let childDirectories = deviceDirectories(in: rootPath)
        let childDirectoryMap = Dictionary(uniqueKeysWithValues: childDirectories.map { ($0.lastPathComponent, $0) })

        var candidates: [CleanupCandidate] = []
        var skippedDirectoryCount = 0
        var matchedUDIDs = Set<String>()
        var recommendedIdentifier: String?

        for device in parsedDevices {
            guard let directory = childDirectoryMap[device.udid] else {
                continue
            }

            matchedUDIDs.insert(device.udid)
            if recommendedIdentifier == nil, device.isAvailable {
                recommendedIdentifier = device.udid
            }

            let size = directorySize(atPath: directory.path)
            let runtimeDescription = runtimeDisplayName(for: device.runtimeIdentifier)
            let candidate = CleanupCandidate(
                identifier: device.udid,
                title: device.name,
                path: directory.path,
                sizeBytes: size,
                detail: runtimeDescription,
                isRecommendedToKeep: false
            )
            candidates.append(candidate)
        }

        skippedDirectoryCount = childDirectories.filter { !matchedUDIDs.contains($0.lastPathComponent) }.count

        let finalizedCandidates = candidates.map { candidate in
            CleanupCandidate(
                identifier: candidate.identifier,
                title: candidate.title,
                path: candidate.path,
                sizeBytes: candidate.sizeBytes,
                detail: candidate.detail,
                isRecommendedToKeep: candidate.identifier == recommendedIdentifier
            )
        }

        let totalSize = finalizedCandidates.reduce(Int64(0)) { $0 + ($1.sizeBytes ?? 0) }
        guard !finalizedCandidates.isEmpty else {
            let skippedText = skippedDirectoryCount > 0 ? " Skipped \(skippedDirectoryCount) unmapped director\(skippedDirectoryCount == 1 ? "y" : "ies")." : ""
            return ScannedItem(
                rule: rule,
                status: .missing,
                sizeBytes: 0,
                detail: "No simulator device directories matched simctl metadata.\(skippedText)"
            )
        }

        let candidateSummary = finalizedCandidates.map { candidate in
            let runtime = candidate.detail.map { " (\($0))" } ?? ""
            return "\(candidate.title)\(runtime)"
        }.joined(separator: ", ")

        let skippedText = skippedDirectoryCount > 0 ? " Skipped \(skippedDirectoryCount) unmapped director\(skippedDirectoryCount == 1 ? "y" : "ies")." : ""

        return ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: totalSize,
            detail: "\(candidateSummary).\(skippedText)",
            candidates: finalizedCandidates
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

    private func deviceDirectories(in rootPath: String) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: rootPath) else {
            return []
        }

        return contents.compactMap { entry in
            let url = URL(fileURLWithPath: rootPath, isDirectory: true).appendingPathComponent(entry, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            return url
        }
    }

    private func parseSimulatorDevices(json: String) -> Result<[SimulatorDeviceMetadata], SimulatorDeviceParseError> {
        guard let data = json.data(using: .utf8) else {
            return .failure(.invalidJSON)
        }
        guard
            let root = try? JSONSerialization.jsonObject(with: data),
            let dictionary = root as? [String: Any],
            let devices = dictionary["devices"] as? [String: Any]
        else {
            return .failure(.invalidJSON)
        }

        var parsed: [SimulatorDeviceMetadata] = []
        for (runtimeIdentifier, rawDevices) in devices {
            guard let deviceArray = rawDevices as? [[String: Any]] else {
                continue
            }

            for rawDevice in deviceArray {
                guard
                    let udid = rawDevice["udid"] as? String,
                    let name = rawDevice["name"] as? String
                else {
                    continue
                }

                parsed.append(
                    SimulatorDeviceMetadata(
                        runtimeIdentifier: runtimeIdentifier,
                        udid: udid,
                        name: name,
                        isAvailable: rawDevice["isAvailable"] as? Bool ?? true
                    )
                )
            }
        }

        return .success(parsed)
    }

    private func runtimeDisplayName(for runtimeIdentifier: String) -> String {
        guard let suffix = runtimeIdentifier.split(separator: ".").last else {
            return runtimeIdentifier
        }

        let parts = suffix.split(separator: "-")
        guard !parts.isEmpty else {
            return runtimeIdentifier
        }

        let platform = String(parts[0])
        let versionParts = parts.dropFirst().map(String.init)
        guard !versionParts.isEmpty else {
            return platform
        }

        return "\(platform) \(versionParts.joined(separator: "."))"
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

private struct SimulatorDeviceMetadata {
    let runtimeIdentifier: String
    let udid: String
    let name: String
    let isAvailable: Bool
}

private enum SimulatorDeviceParseError: Error {
    case invalidJSON
}
