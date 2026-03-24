import XCTest
@testable import XCleanCore

final class UpdaterTests: XCTestCase {
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
}
