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

    func testCleanerDeletesOnlySelectedSimulatorDeviceSubdirectories() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let devicesRoot = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
        let selectedDevice = devicesRoot.appendingPathComponent("11111111-2222-3333-4444-555555555555", isDirectory: true)
        let keptDevice = devicesRoot.appendingPathComponent("22222222-3333-4444-5555-666666666666", isDirectory: true)
        try FileManager.default.createDirectory(at: selectedDevice, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: keptDevice, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 8).write(to: selectedDevice.appendingPathComponent("selected.bin"))
        try Data(repeating: 0x2, count: 8).write(to: keptDevice.appendingPathComponent("kept.bin"))

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
        let candidate = CleanupCandidate(
            identifier: selectedDevice.lastPathComponent,
            title: "iPhone 15",
            path: selectedDevice.path,
            sizeBytes: 8,
            detail: "iOS 17.4",
            isRecommendedToKeep: false
        )
        let item = ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: 8,
            detail: nil,
            candidates: [candidate]
        )

        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: home,
                allowedPaths: [devicesRoot.path]
            ),
            processRunner: MockProcessRunner()
        )

        let results = cleaner.delete(items: [item])

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.item.rule.title, "iPhone 15")
        XCTAssertEqual(results.first?.status, .deleted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: devicesRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: selectedDevice.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keptDevice.path))
    }

    func testCleanerRejectsUnsafeSimulatorDevicePaths() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let devicesRoot = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
        let safeDevice = devicesRoot.appendingPathComponent("11111111-2222-3333-4444-555555555555", isDirectory: true)
        let unsafeDevice = FileManager.default.temporaryDirectory
            .appendingPathComponent("outside-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: devicesRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: safeDevice, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unsafeDevice, withIntermediateDirectories: true)

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
        let candidate = CleanupCandidate(
            identifier: unsafeDevice.lastPathComponent,
            title: "Unsafe iPhone",
            path: unsafeDevice.path,
            sizeBytes: 0,
            detail: "iOS 17.4",
            isRecommendedToKeep: false
        )
        let item = ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: 0,
            detail: nil,
            candidates: [candidate]
        )

        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: home,
                allowedPaths: [devicesRoot.path]
            ),
            processRunner: MockProcessRunner()
        )

        let results = cleaner.delete(items: [item])

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.item.rule.title, "Unsafe iPhone")
        XCTAssertEqual(results.first?.status, .failed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: devicesRoot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: safeDevice.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unsafeDevice.path))
    }

    func testCleanerProcessesMixedSimulatorCandidatesIndependently() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let devicesRoot = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
        let safeDevice = devicesRoot.appendingPathComponent("11111111-2222-3333-4444-555555555555", isDirectory: true)
        let missingDevice = devicesRoot.appendingPathComponent("22222222-3333-4444-5555-666666666666", isDirectory: true)
        let unsafeDevice = FileManager.default.temporaryDirectory
            .appendingPathComponent("outside-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: safeDevice, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unsafeDevice, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 8).write(to: safeDevice.appendingPathComponent("selected.bin"))

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
        let item = ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: 8,
            detail: nil,
            candidates: [
                CleanupCandidate(
                    identifier: safeDevice.lastPathComponent,
                    title: "Safe iPhone",
                    path: safeDevice.path,
                    sizeBytes: 8,
                    detail: "iOS 17.4",
                    isRecommendedToKeep: false
                ),
                CleanupCandidate(
                    identifier: missingDevice.lastPathComponent,
                    title: "Missing iPhone",
                    path: missingDevice.path,
                    sizeBytes: 0,
                    detail: "iOS 17.4",
                    isRecommendedToKeep: false
                ),
                CleanupCandidate(
                    identifier: unsafeDevice.lastPathComponent,
                    title: "Unsafe iPhone",
                    path: unsafeDevice.path,
                    sizeBytes: 0,
                    detail: "iOS 17.4",
                    isRecommendedToKeep: false
                )
            ]
        )

        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(
                homeDirectory: home,
                allowedPaths: [devicesRoot.path]
            ),
            processRunner: MockProcessRunner()
        )

        let results = cleaner.delete(items: [item])

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.map(\.item.rule.title), ["Safe iPhone", "Missing iPhone", "Unsafe iPhone"])
        XCTAssertEqual(results.map(\.status), [.deleted, .skipped, .failed])
        XCTAssertFalse(FileManager.default.fileExists(atPath: safeDevice.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unsafeDevice.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: devicesRoot.path))
    }

    func testCleanerRejectsDeleteItemForMultiCandidateSimulatorSelection() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let devicesRoot = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices").path
        let rule = CleanupRule(
            identifier: "simulator-devices",
            title: "CoreSimulator/Devices",
            category: .simulators,
            kind: .directory,
            path: devicesRoot,
            description: "Simulator device data",
            recommendation: .caution,
            tier: .careful
        )
        let item = ScannedItem(
            rule: rule,
            status: .available,
            sizeBytes: 16,
            detail: nil,
            candidates: [
                CleanupCandidate(
                    identifier: "one",
                    title: "iPhone 15",
                    path: devicesRoot + "/one",
                    sizeBytes: 8,
                    detail: "iOS 17.4",
                    isRecommendedToKeep: false
                ),
                CleanupCandidate(
                    identifier: "two",
                    title: "iPhone 16",
                    path: devicesRoot + "/two",
                    sizeBytes: 8,
                    detail: "iOS 18.0",
                    isRecommendedToKeep: false
                )
            ]
        )

        let cleaner = Cleaner(
            fileManager: .default,
            pathSafetyValidator: PathSafetyValidator(homeDirectory: home, allowedPaths: [devicesRoot]),
            processRunner: MockProcessRunner()
        )

        let result = cleaner.delete(item: item)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.message, "Use delete(items:) for simulator device selections.")
    }
}
