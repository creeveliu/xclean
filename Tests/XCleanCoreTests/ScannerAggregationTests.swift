import XCTest
@testable import XCleanCore

final class ScannerAggregationTests: XCTestCase {
    func testScannerAggregatesCategoryTotals() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let derivedData = root.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        let previews = root.appendingPathComponent("Library/Developer/Xcode/UserData/Previews", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 32).write(to: derivedData.appendingPathComponent("a.bin"))
        try Data(repeating: 0x1, count: 16).write(to: previews.appendingPathComponent("b.bin"))

        let rules = [
            CleanupRule(
                identifier: "derived-data",
                title: "DerivedData",
                category: .buildArtifacts,
                kind: .directory,
                path: derivedData.path,
                description: "Build products",
                recommendation: .recommended
            ),
            CleanupRule(
                identifier: "previews",
                title: "Previews",
                category: .previewsAndDocs,
                kind: .directory,
                path: previews.path,
                description: "SwiftUI previews",
                recommendation: .recommended
            ),
        ]

        let scanner = Scanner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: root,
                allowedPaths: rules.compactMap(\.path)
            ),
            processRunner: MockProcessRunner()
        )

        let report = scanner.scan(rules: rules)

        let buildSummary = try XCTUnwrap(report.categories.first(where: { $0.category == .buildArtifacts }))
        let previewsSummary = try XCTUnwrap(report.categories.first(where: { $0.category == .previewsAndDocs }))

        XCTAssertEqual(buildSummary.totalSizeBytes, 32)
        XCTAssertEqual(previewsSummary.totalSizeBytes, 16)
        XCTAssertEqual(report.totalSizeBytes, 48)
    }
}
