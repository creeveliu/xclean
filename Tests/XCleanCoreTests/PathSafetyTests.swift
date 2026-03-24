import XCTest
@testable import XCleanCore

final class PathSafetyTests: XCTestCase {
    func testAllowsPathInsideHomeWhenExplicitlyPermitted() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let allowed = [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData").path
        ]

        let validator = PathSafetyValidator(homeDirectory: home, allowedPaths: allowed)

        XCTAssertTrue(validator.isSafe(path: "/tmp/home/Library/Developer/Xcode/DerivedData"))
    }

    func testRejectsPathOutsideHome() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let validator = PathSafetyValidator(homeDirectory: home, allowedPaths: [])

        XCTAssertFalse(validator.isSafe(path: "/tmp/other/Library/Developer/Xcode/DerivedData"))
    }
}
