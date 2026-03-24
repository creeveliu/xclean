import XCTest
@testable import XCleanCore

final class CleanerTests: XCTestCase {
    func testCleanerSkipsMissingDirectoryWithoutFailure() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let path = home.appendingPathComponent("Library/Developer/Xcode/DerivedData").path
        let rule = CleanupRule(
            identifier: "derived-data",
            title: "DerivedData",
            category: .buildArtifacts,
            kind: .directory,
            path: path,
            description: "Build products",
            recommendation: .recommended
        )
        let item = ScannedItem(rule: rule, status: .missing, sizeBytes: 0, detail: nil)

        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(homeDirectory: home, allowedPaths: [path]),
            processRunner: MockProcessRunner()
        )

        let result = cleaner.delete(item: item)
        XCTAssertEqual(result.status, .skipped)
    }
}
