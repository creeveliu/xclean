import Foundation

public enum XCleanCLI {
    public static let version = "0.1.2"

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
        let ui = TerminalUI()
        let report = scanner.scan(rules: rules)

        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "interactive"

        switch command {
        case "interactive", "clean":
            ui.runInteractiveClean(report: report, cleaner: cleaner)
        case "scan":
            ui.printReport(report)
        case "update":
            let result = updater.update(currentExecutablePath: currentExecutablePath())
            if !result.standardOutput.isEmpty {
                print(result.standardOutput, terminator: "")
            }
            if !result.standardError.isEmpty {
                fputs(result.standardError, stderr)
            }
            Foundation.exit(result.exitCode == 0 ? 0 : 1)
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
              xclean update    Reinstall the latest version
              xclean uninstall Remove the current binary
              xclean version   Print version
            """
        )
    }

    private static func currentExecutablePath() -> String {
        if let bundlePath = Bundle.main.executableURL?.path {
            return bundlePath
        }
        return ProcessInfo.processInfo.arguments.first ?? "xclean"
    }
}
