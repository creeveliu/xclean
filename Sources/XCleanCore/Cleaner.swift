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
        items.map(delete(item:))
    }

    public func delete(item: ScannedItem) -> DeleteResult {
        switch item.rule.kind {
        case .directory:
            return deleteDirectory(item: item)
        case .command:
            return deleteUnavailableSimulators(item: item)
        }
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

    private func deleteUnavailableSimulators(item: ScannedItem) -> DeleteResult {
        let result = processRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "delete", "unavailable"]
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
