import Foundation

public struct Updater {
    private let installerURL: URL
    private let processRunner: ProcessRunning

    public init(
        installerURL: URL = URL(string: "https://raw.githubusercontent.com/creeveliu/xclean/main/install.sh")!,
        processRunner: ProcessRunning = ProcessRunner()
    ) {
        self.installerURL = installerURL
        self.processRunner = processRunner
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
}
