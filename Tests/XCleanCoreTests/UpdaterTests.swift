import XCTest
@testable import XCleanCore

final class UpdaterTests: XCTestCase {
    func testUpdateDefaultsToCloudflareInstallerURL() {
        var capturedArguments: [String] = []
        let runner = MockProcessRunner(
            nextResult: ProcessResult(exitCode: 0, standardOutput: "", standardError: ""),
            onRun: { _, arguments, _ in
                capturedArguments = arguments
            }
        )

        let updater = Updater(processRunner: runner)
        _ = updater.update(currentExecutablePath: "/Users/test/.local/bin/xclean")

        XCTAssertEqual(
            capturedArguments,
            [
                "-o",
                "pipefail",
                "-lc",
                "curl -fsSL https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh | bash"
            ]
        )
    }

    func testUpdateUsesCurrentExecutableDirectoryAsInstallDir() throws {
        let updater = Updater(installerURL: URL(string: "https://example.com/install.sh")!)
        let executable = "/Users/test/.local/bin/xclean"
        let installDir = updater.installDirectory(forExecutablePath: executable)

        XCTAssertEqual(installDir, "/Users/test/.local/bin")
    }

    func testUpdateInvokesInstallerScriptWithExpectedEnvironment() {
        var capturedExecutable = ""
        var capturedArguments: [String] = []
        var capturedEnvironment: [String: String] = [:]

        let runner = MockProcessRunner(
            nextResult: ProcessResult(exitCode: 0, standardOutput: "", standardError: ""),
            onRun: { executable, arguments, environment in
                capturedExecutable = executable
                capturedArguments = arguments
                capturedEnvironment = environment ?? [:]
            }
        )

        let updater = Updater(
            installerURL: URL(string: "https://example.com/install.sh")!,
            processRunner: runner
        )

        let result = updater.update(currentExecutablePath: "/Users/test/.local/bin/xclean")

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(capturedExecutable, "/bin/bash")
        XCTAssertEqual(capturedArguments, ["-o", "pipefail", "-lc", "curl -fsSL https://example.com/install.sh | bash"])
        XCTAssertEqual(capturedEnvironment["XCLEAN_INSTALL_DIR"], "/Users/test/.local/bin")
    }

    func testUninstallRemovesCurrentExecutable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let installDir = root.appendingPathComponent(".local/bin", isDirectory: true)
        let executable = installDir.appendingPathComponent("xclean")

        try FileManager.default.createDirectory(at: installDir, withIntermediateDirectories: true)
        try "stub".data(using: .utf8)?.write(to: executable)

        let updater = Updater(installerURL: URL(string: "https://example.com/install.sh")!)
        let result = updater.uninstall(currentExecutablePath: executable.path)

        XCTAssertEqual(result.status, .deleted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: executable.path))
    }

    func testUninstallRemovesInstallDirectoryWhenItBecomesEmpty() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let installDir = root.appendingPathComponent(".local/bin", isDirectory: true)
        let executable = installDir.appendingPathComponent("xclean")

        try FileManager.default.createDirectory(at: installDir, withIntermediateDirectories: true)
        try "stub".data(using: .utf8)?.write(to: executable)

        let updater = Updater(installerURL: URL(string: "https://example.com/install.sh")!)
        _ = updater.uninstall(currentExecutablePath: executable.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: installDir.path))
    }
}
