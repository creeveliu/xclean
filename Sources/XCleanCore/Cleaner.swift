import Foundation

public struct Cleaner {
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

    public func delete(items: [ScannedItem]) -> [DeleteResult] {
        items.flatMap(deleteResults(for:))
    }

    public func delete(item: ScannedItem) -> DeleteResult {
        if item.rule.identifier == "simulator-devices",
           let candidates = item.candidates,
           candidates.count > 1 {
            return DeleteResult(
                item: item,
                status: .failed,
                message: "Use delete(items:) for simulator device selections."
            )
        }

        return deleteResults(for: item).first ?? DeleteResult(item: item, status: .failed, message: "Nothing to delete.")
    }

    private func deleteDirectory(item: ScannedItem) -> DeleteResult {
        guard let path = item.rule.path else {
            return DeleteResult(item: item, status: .failed, message: "Missing path.")
        }
        guard pathSafetyValidator.isSafe(path: path) else {
            return DeleteResult(item: item, status: .failed, message: "Blocked by safety rules.")
        }
        guard fileManager.fileExists(atPath: path) else {
            return DeleteResult(item: item, status: .skipped, message: "Path not found.")
        }

        do {
            try fileManager.removeItem(atPath: path)
            return DeleteResult(item: item, status: .deleted, message: nil)
        } catch {
            return DeleteResult(item: item, status: .failed, message: error.localizedDescription)
        }
    }

    private func deleteResults(for item: ScannedItem) -> [DeleteResult] {
        switch item.rule.kind {
        case .directory:
            if item.rule.identifier == "simulator-devices" {
                return deleteSimulatorDeviceCandidates(item: item)
            }
            return [deleteDirectory(item: item)]
        case .command:
            return [deleteUnavailableSimulators(item: item)]
        }
    }

    private func deleteSimulatorDeviceCandidates(item: ScannedItem) -> [DeleteResult] {
        guard let candidates = item.candidates, !candidates.isEmpty else {
            return [
                DeleteResult(
                    item: item,
                    status: .failed,
                    message: "No simulator device candidates selected."
                )
            ]
        }

        return candidates.map { candidate in
            let candidateItem = item.itemForCandidate(candidate)

            guard pathSafetyValidator.isSafe(path: candidate.path, allowingDescendantsOfAllowedPaths: true) else {
                return DeleteResult(
                    item: candidateItem,
                    status: .failed,
                    message: "Blocked by safety rules."
                )
            }

            guard fileManager.fileExists(atPath: candidate.path) else {
                return DeleteResult(
                    item: candidateItem,
                    status: .skipped,
                    message: "Path not found."
                )
            }

            do {
                try fileManager.removeItem(atPath: candidate.path)
                return DeleteResult(item: candidateItem, status: .deleted, message: nil)
            } catch {
                return DeleteResult(
                    item: candidateItem,
                    status: .failed,
                    message: error.localizedDescription
                )
            }
        }
    }

    private func deleteUnavailableSimulators(item: ScannedItem) -> DeleteResult {
        let result = processRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "delete", "unavailable"],
            environment: nil
        )

        guard result.exitCode == 0 else {
            let message = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            return DeleteResult(
                item: item,
                status: .failed,
                message: message.isEmpty ? "xcrun simctl delete unavailable failed." : message
            )
        }

        return DeleteResult(item: item, status: .deleted, message: nil)
    }
}
