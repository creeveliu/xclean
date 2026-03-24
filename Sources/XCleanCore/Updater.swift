import Foundation

public enum UninstallStatus: Sendable {
    case deleted
    case skipped
    case failed
}

public struct UninstallResult: Sendable {
    public let status: UninstallStatus
    public let message: String?
}

public struct Updater {
    private let installerURL: URL
    private let processRunner: ProcessRunning
    private let fileManager: FileManager

    public init(
        installerURL: URL = URL(string: "https://raw.githubusercontent.com/creeveliu/xclean/main/install.sh")!,
        processRunner: ProcessRunning = ProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.installerURL = installerURL
        self.processRunner = processRunner
        self.fileManager = fileManager
    }

    public func installDirectory(forExecutablePath path: String) -> String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
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
}
