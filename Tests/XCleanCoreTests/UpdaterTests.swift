import XCTest
@testable import XCleanCore

final class UpdaterTests: XCTestCase {
    func testRunUpdateCommandPrintsCurrentVersionAndLatestMessageWhenUpToDate() {
        let updater = MockUpdating(
            checkResult: .success(
                UpdateCheckStatus(currentVersion: "0.1.7", latestVersion: "0.1.7", needsUpdate: false)
            )
        )
        var output: [String] = []
        var errors: [String] = []

        let exitCode = XCleanCLI.runUpdateCommand(
            version: "0.1.7",
            currentExecutablePath: "/Users/test/.local/bin/xclean",
            updater: updater,
            stdout: { output.append($0) },
            stderr: { errors.append($0) }
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(
            output,
            [
                "当前版本：0.1.7\n",
                "正在检查更新中...\n",
                "当前是最新版本（0.1.7）\n"
            ]
        )
        XCTAssertTrue(errors.isEmpty)
        XCTAssertFalse(updater.didRunInstall)
    }

    func testRunUpdateCommandPrintsNewVersionAndRunsInstallWhenUpgradeIsAvailable() {
        let updater = MockUpdating(
            checkResult: .success(
                UpdateCheckStatus(currentVersion: "0.1.7", latestVersion: "0.1.8", needsUpdate: true)
            ),
            installResult: ProcessResult(exitCode: 0, standardOutput: "installed\n", standardError: "")
        )
        var output: [String] = []
        var errors: [String] = []

        let exitCode = XCleanCLI.runUpdateCommand(
            version: "0.1.7",
            currentExecutablePath: "/Users/test/.local/bin/xclean",
            updater: updater,
            stdout: { output.append($0) },
            stderr: { errors.append($0) }
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(
            output,
            [
                "当前版本：0.1.7\n",
                "正在检查更新中...\n",
                "发现新版本：0.1.8，开始安装...\n",
                "installed\n"
            ]
        )
        XCTAssertTrue(errors.isEmpty)
        XCTAssertTrue(updater.didRunInstall)
    }

    func testRunUpdateCommandReportsCheckFailureAndDoesNotInstall() {
        let updater = MockUpdating(
            checkResult: .failure(.remoteLookupFailed("network error"))
        )
        var output: [String] = []
        var errors: [String] = []

        let exitCode = XCleanCLI.runUpdateCommand(
            version: "0.1.7",
            currentExecutablePath: "/Users/test/.local/bin/xclean",
            updater: updater,
            stdout: { output.append($0) },
            stderr: { errors.append($0) }
        )

        XCTAssertEqual(exitCode, 1)
        XCTAssertEqual(
            output,
            [
                "当前版本：0.1.7\n",
                "正在检查更新中...\n"
            ]
        )
        XCTAssertEqual(errors, ["network error\n"])
        XCTAssertFalse(updater.didRunInstall)
    }

    func testCheckForUpdatesTreatsMatchingNormalizedVersionsAsUpToDate() {
        let runner = MockProcessRunner(
            nextResult: ProcessResult(exitCode: 0, standardOutput: "v0.1.7\n", standardError: "")
        )
        let updater = Updater(processRunner: runner)

        let result = updater.checkForUpdates(currentVersion: "0.1.7")

        switch result {
        case .success(let status):
            XCTAssertEqual(status.currentVersion, "0.1.7")
            XCTAssertEqual(status.latestVersion, "0.1.7")
            XCTAssertFalse(status.needsUpdate)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testCheckForUpdatesDetectsWhenRemoteVersionIsNewer() {
        let runner = MockProcessRunner(
            nextResult: ProcessResult(exitCode: 0, standardOutput: "v0.1.8\n", standardError: "")
        )
        let updater = Updater(processRunner: runner)

        let result = updater.checkForUpdates(currentVersion: "0.1.7")

        switch result {
        case .success(let status):
            XCTAssertEqual(status.currentVersion, "0.1.7")
            XCTAssertEqual(status.latestVersion, "0.1.8")
            XCTAssertTrue(status.needsUpdate)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testCheckForUpdatesFailsWhenRemoteVersionIsMalformed() {
        let runner = MockProcessRunner(
            nextResult: ProcessResult(exitCode: 0, standardOutput: "latest\n", standardError: "")
        )
        let updater = Updater(processRunner: runner)

        let result = updater.checkForUpdates(currentVersion: "0.1.7")

        switch result {
        case .success(let status):
            XCTFail("Expected failure, got \(status)")
        case .failure(let error):
            XCTAssertEqual(error.localizedDescription, "Received malformed remote version: latest")
        }
    }

    func testCheckForUpdatesFailsWhenRemoteLookupFails() {
        let runner = MockProcessRunner(
            nextResult: ProcessResult(exitCode: 1, standardOutput: "", standardError: "network error")
        )
        let updater = Updater(processRunner: runner)

        let result = updater.checkForUpdates(currentVersion: "0.1.7")

        switch result {
        case .success(let status):
            XCTFail("Expected failure, got \(status)")
        case .failure(let error):
            XCTAssertEqual(error.localizedDescription, "network error")
        }
    }

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

private final class MockUpdating: Updating {
    private let checkResult: Result<UpdateCheckStatus, UpdateCheckError>
    private let installResult: ProcessResult
    private(set) var didRunInstall = false

    init(
        checkResult: Result<UpdateCheckStatus, UpdateCheckError>,
        installResult: ProcessResult = ProcessResult(exitCode: 0, standardOutput: "", standardError: "")
    ) {
        self.checkResult = checkResult
        self.installResult = installResult
    }

    func checkForUpdates(currentVersion: String) -> Result<UpdateCheckStatus, UpdateCheckError> {
        checkResult
    }

    func update(currentExecutablePath: String) -> ProcessResult {
        didRunInstall = true
        return installResult
    }
}
