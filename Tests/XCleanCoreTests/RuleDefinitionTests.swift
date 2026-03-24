import XCTest
@testable import XCleanCore

final class RuleDefinitionTests: XCTestCase {
    func testDefaultRulesContainExpectedXcodeTargets() {
        let home = URL(fileURLWithPath: "/tmp/example-home", isDirectory: true)
        let rules = CleanupRule.defaultRules(homeDirectory: home)

        XCTAssertTrue(rules.contains(where: {
            $0.identifier == "derived-data" &&
            $0.kind == .directory &&
            $0.category == .buildArtifacts &&
            $0.path == home.appendingPathComponent("Library/Developer/Xcode/DerivedData").path
        }))

        XCTAssertTrue(rules.contains(where: {
            $0.identifier == "simctl-unavailable" &&
            $0.kind == .command &&
            $0.category == .simulators
        }))
    }
}
