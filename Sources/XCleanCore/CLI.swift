import Foundation

public enum XCleanCLI {
    public static let version = "0.1.8"

    public static func main() {
        let updater = Updater()
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let rules = CleanupRule.defaultRules(homeDirectory: homeDirectory)
        let validator = PathSafetyValidator(
            homeDirectory: homeDirectory,
            allowedPaths: rules.compactMap(\.path)
        )
        let scanner = Scanner(pathSafetyValidator: validator)
        let cleaner = Cleaner(pathSafetyValidator: validator)
        let ui = TerminalUI(language: .current)
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "interactive"

        switch command {
        case "interactive", "clean":
            ui.runInteractiveClean(reportProvider: {
                scanner.scan(rules: rules)
            }, cleaner: cleaner)
        case "scan":
            let report = scanner.scan(rules: rules)
            ui.printReport(report)
        case "update":
            let exitCode = runUpdateCommand(
                version: version,
                currentExecutablePath: currentExecutablePath(),
                updater: updater,
                stdout: { print($0, terminator: "") },
                stderr: { fputs($0, stderr) }
            )
            Foundation.exit(exitCode)
        case "uninstall":
            let result = updater.uninstall(currentExecutablePath: currentExecutablePath())
            switch result.status {
            case .deleted:
                print("xclean uninstalled.")
                Foundation.exit(0)
            case .skipped:
                if let message = result.message {
                    print(message)
                }
                Foundation.exit(0)
            case .failed:
                if let message = result.message {
                    fputs("\(message)\n", stderr)
                }
                Foundation.exit(1)
            }
        case "version", "--version", "-v":
            print(version)
        case "-h", "--help", "help":
            printUsage()
        default:
            fputs("Unknown command: \(command)\n", stderr)
            printUsage()
            Foundation.exit(1)
        }
    }

    private static func printUsage() {
        print(
            """
            Usage:
              xclean           Start interactive cleanup
              xclean clean     Start interactive cleanup
              xclean scan      Scan only
              xclean update    Check for updates and install if available
              xclean uninstall Remove the current binary
              xclean version   Print version
            """
        )
    }

    static func runUpdateCommand(
        version: String,
        currentExecutablePath: String,
        updater: Updating,
        stdout: (String) -> Void,
        stderr: (String) -> Void
    ) -> Int32 {
        stdout("当前版本：\(version)\n")
        stdout("正在检查更新中...\n")

        switch updater.checkForUpdates(currentVersion: version) {
        case .success(let status):
            if !status.needsUpdate {
                stdout("当前是最新版本（\(status.latestVersion)）\n")
                return 0
            }

            stdout("发现新版本：\(status.latestVersion)，开始安装...\n")
            let result = updater.update(currentExecutablePath: currentExecutablePath)
            if !result.standardOutput.isEmpty {
                stdout(result.standardOutput)
            }
            if !result.standardError.isEmpty {
                stderr(result.standardError)
            }
            return result.exitCode == 0 ? 0 : 1
        case .failure(let error):
            stderr("\(error.localizedDescription)\n")
            return 1
        }
    }

    private static func currentExecutablePath() -> String {
        if let bundlePath = Bundle.main.executableURL?.path {
            return bundlePath
        }
        return ProcessInfo.processInfo.arguments.first ?? "xclean"
    }
}
