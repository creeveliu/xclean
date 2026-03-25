import Foundation

public struct UpdateCheckStatus: Sendable, Equatable {
    public let currentVersion: String
    public let latestVersion: String
    public let needsUpdate: Bool
}

public protocol Updating {
    func checkForUpdates(currentVersion: String) -> Result<UpdateCheckStatus, UpdateCheckError>
    func update(currentExecutablePath: String) -> ProcessResult
}

public enum UpdateCheckError: LocalizedError, Sendable, Equatable {
    case remoteLookupFailed(String)
    case malformedRemoteVersion(String)
    case malformedCurrentVersion(String)
    case malformedReleasePayload

    public var errorDescription: String? {
        switch self {
        case .remoteLookupFailed(let message):
            return message
        case .malformedRemoteVersion(let version):
            return "Received malformed remote version: \(version)"
        case .malformedCurrentVersion(let version):
            return "Received malformed current version: \(version)"
        case .malformedReleasePayload:
            return "Received malformed release metadata."
        }
    }
}

public enum UninstallStatus: Sendable {
    case deleted
    case skipped
    case failed
}

public struct UninstallResult: Sendable {
    public let status: UninstallStatus
    public let message: String?
}

public struct Updater: Updating {
    private let installerURL: URL
    private let latestReleaseURL: URL
    private let processRunner: ProcessRunning
    private let fileManager: FileManager

    public init(
        installerURL: URL = URL(string: "https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh")!,
        latestReleaseURL: URL = URL(string: "https://api.github.com/repos/creeveliu/xclean/releases/latest")!,
        processRunner: ProcessRunning = ProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.installerURL = installerURL
        self.latestReleaseURL = latestReleaseURL
        self.processRunner = processRunner
        self.fileManager = fileManager
    }

    public func installDirectory(forExecutablePath path: String) -> String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    public func checkForUpdates(currentVersion: String) -> Result<UpdateCheckStatus, UpdateCheckError> {
        guard let current = SemanticVersion(currentVersion) else {
            return .failure(.malformedCurrentVersion(currentVersion))
        }

        let result = processRunner.run(
            executable: "/usr/bin/env",
            arguments: ["curl", "-fsSL", latestReleaseURL.absoluteString],
            environment: nil
        )

        guard result.exitCode == 0 else {
            let message = result.standardError.isEmpty ? "Failed to check for updates." : result.standardError
            return .failure(.remoteLookupFailed(message))
        }

        let payload = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let latestValue = extractLatestVersion(from: payload)

        guard let latestValue else {
            return .failure(.malformedReleasePayload)
        }

        guard let latest = SemanticVersion(latestValue) else {
            return .failure(.malformedRemoteVersion(latestValue))
        }

        return .success(
            UpdateCheckStatus(
                currentVersion: current.normalizedString,
                latestVersion: latest.normalizedString,
                needsUpdate: latest > current
            )
        )
    }

    public func update(currentExecutablePath: String) -> ProcessResult {
        let installDirectory = installDirectory(forExecutablePath: currentExecutablePath)
        var environment = ProcessInfo.processInfo.environment
        environment["XCLEAN_INSTALL_DIR"] = installDirectory

        return processRunner.run(
            executable: "/bin/bash",
            arguments: ["-o", "pipefail", "-lc", "curl -fsSL \(installerURL.absoluteString) | bash"],
            environment: environment
        )
    }

    public func uninstall(currentExecutablePath: String) -> UninstallResult {
        let executablePath = URL(fileURLWithPath: currentExecutablePath).path
        let installDirectory = installDirectory(forExecutablePath: executablePath)

        guard fileManager.fileExists(atPath: executablePath) else {
            return UninstallResult(status: .skipped, message: "Executable not found.")
        }

        do {
            try fileManager.removeItem(atPath: executablePath)

            if directoryIsEmpty(atPath: installDirectory) {
                try? fileManager.removeItem(atPath: installDirectory)
            }

            return UninstallResult(status: .deleted, message: nil)
        } catch {
            return UninstallResult(status: .failed, message: error.localizedDescription)
        }
    }

    private func directoryIsEmpty(atPath path: String) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return false
        }
        return contents.isEmpty
    }

    private func extractLatestVersion(from payload: String) -> String? {
        if payload.hasPrefix("{"),
           let data = payload.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tagName = object["tag_name"] as? String {
            return tagName
        }

        if payload.isEmpty {
            return nil
        }

        return payload
    }
}

private struct SemanticVersion: Comparable {
    let components: [Int]
    let normalizedString: String

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)

        guard !value.isEmpty, !parts.isEmpty else {
            return nil
        }

        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else {
            return nil
        }

        self.components = numbers
        self.normalizedString = numbers.map(String.init).joined(separator: ".")
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)

        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0

            if left != right {
                return left < right
            }
        }

        return false
    }
}
