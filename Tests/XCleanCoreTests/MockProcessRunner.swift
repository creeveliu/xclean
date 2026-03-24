import Foundation
@testable import XCleanCore

struct MockProcessRunner: ProcessRunning {
    var nextResult = ProcessResult(exitCode: 0, standardOutput: "", standardError: "")
    var onRun: ((String, [String], [String: String]?) -> Void)?

    func run(executable: String, arguments: [String], environment: [String: String]?) -> ProcessResult {
        onRun?(executable, arguments, environment)
        return nextResult
    }
}
