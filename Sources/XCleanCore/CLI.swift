import Foundation

public enum XCleanCLI {
    public static let version = "0.1.0"

    public static func main() {
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
              xclean version   Print version
            """
        )
    }
}
