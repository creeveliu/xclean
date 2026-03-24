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

    func testScannerExpandsSimulatorDevicesUsingSimctlMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let devicesRoot = root.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
        try FileManager.default.createDirectory(at: devicesRoot, withIntermediateDirectories: true)

        let mappedUDID = "11111111-2222-3333-4444-555555555555"
        let secondMappedUDID = "22222222-3333-4444-5555-666666666666"
        let mappedDevice = devicesRoot.appendingPathComponent(mappedUDID, isDirectory: true)
        let secondMappedDevice = devicesRoot.appendingPathComponent(secondMappedUDID, isDirectory: true)
        let unmappedDevice = devicesRoot.appendingPathComponent("orphan-device", isDirectory: true)
        try FileManager.default.createDirectory(at: mappedDevice, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondMappedDevice, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unmappedDevice, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 24).write(to: mappedDevice.appendingPathComponent("mapped.bin"))
        try Data(repeating: 0x1, count: 18).write(to: secondMappedDevice.appendingPathComponent("second.bin"))
        try Data(repeating: 0x2, count: 12).write(to: unmappedDevice.appendingPathComponent("orphan.bin"))

        let rule = CleanupRule(
            identifier: "simulator-devices",
            title: "CoreSimulator/Devices",
            category: .simulators,
            kind: .directory,
            path: devicesRoot.path,
            description: "Simulator device data",
            recommendation: .caution,
            tier: .careful
        )

        var capturedExecutable = ""
        var capturedArguments: [String] = []
        let runner = MockProcessRunner(
            nextResult: ProcessResult(
                exitCode: 0,
                standardOutput: """
                {
                  "devices": {
                    "com.apple.CoreSimulator.SimRuntime.iOS-17-4": [
                      {
                        "udid": "99999999-8888-7777-6666-555555555555",
                        "name": "Unavailable iPhone",
                        "state": "Shutdown",
                        "isAvailable": false
                      },
                      {
                        "udid": "\(mappedUDID)",
                        "name": "Zeta iPhone",
                        "state": "Shutdown",
                        "isAvailable": true
                      },
                      {
                        "udid": "\(secondMappedUDID)",
                        "name": "Alpha iPhone",
                        "state": "Shutdown",
                        "isAvailable": true
                      }
                    ]
                  }
                }
                """,
                standardError: ""
            ),
            onRun: { executable, arguments, _ in
                capturedExecutable = executable
                capturedArguments = arguments
            }
        )

        let scanner = Scanner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: root,
                allowedPaths: [rule.path!]
            ),
            processRunner: runner
        )

        let report = scanner.scan(rules: [rule])
        let simulatorItem = try XCTUnwrap(report.categories.first(where: { $0.category == .simulators })?.items.first)
        let candidates = try XCTUnwrap(simulatorItem.candidates)
        let recommendedCandidates = candidates.filter(\.isRecommendedToKeep)
        let recommendedCandidate = try XCTUnwrap(recommendedCandidates.first)

        XCTAssertEqual(capturedExecutable, "/usr/bin/xcrun")
        XCTAssertEqual(capturedArguments, ["simctl", "list", "devices", "--json"])
        XCTAssertEqual(simulatorItem.sizeBytes, 42)
        XCTAssertNotNil(simulatorItem.detail)
        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates.map(\.identifier), [mappedUDID, secondMappedUDID])
        XCTAssertEqual(recommendedCandidates.count, 1)
        XCTAssertEqual(recommendedCandidate.identifier, mappedUDID)
        XCTAssertEqual(recommendedCandidate.title, "Zeta iPhone")
        XCTAssertEqual(recommendedCandidate.path, mappedDevice.path)
        XCTAssertEqual(candidates.first?.detail, "iOS 17.4")
        XCTAssertTrue(simulatorItem.detail?.contains("orphan-device") == false)
        XCTAssertTrue(simulatorItem.detail?.contains("Zeta iPhone") == true)
        XCTAssertTrue(simulatorItem.detail?.contains("Alpha iPhone") == true)
    }

    func testScannerTreatsMalformedSimctlJSONAsUnavailable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let devicesRoot = root.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
        try FileManager.default.createDirectory(at: devicesRoot, withIntermediateDirectories: true)

        let mappedUDID = "11111111-2222-3333-4444-555555555555"
        let mappedDevice = devicesRoot.appendingPathComponent(mappedUDID, isDirectory: true)
        try FileManager.default.createDirectory(at: mappedDevice, withIntermediateDirectories: true)

        let rule = CleanupRule(
            identifier: "simulator-devices",
            title: "CoreSimulator/Devices",
            category: .simulators,
            kind: .directory,
            path: devicesRoot.path,
            description: "Simulator device data",
            recommendation: .caution,
            tier: .careful
        )

        let runner = MockProcessRunner(
            nextResult: ProcessResult(
                exitCode: 0,
                standardOutput: "{ this is not valid json",
                standardError: ""
            )
        )

        let scanner = Scanner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: root,
                allowedPaths: [rule.path!]
            ),
            processRunner: runner
        )

        let report = scanner.scan(rules: [rule])
        let simulatorItem = try XCTUnwrap(report.categories.first(where: { $0.category == .simulators })?.items.first)

        XCTAssertEqual(simulatorItem.status, .unavailable)
        XCTAssertNil(simulatorItem.sizeBytes)
        XCTAssertNil(simulatorItem.candidates)
        XCTAssertEqual(simulatorItem.detail, "Unable to parse simctl device metadata.")
    }
}
