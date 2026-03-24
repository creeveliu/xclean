import Foundation
@testable import XCleanCore

struct MockProcessRunner: ProcessRunning {
    var nextResult = ProcessResult(exitCode: 0, standardOutput: "", standardError: "")

    func run(executable: String, arguments: [String]) -> ProcessResult {
        nextResult
    }
}
