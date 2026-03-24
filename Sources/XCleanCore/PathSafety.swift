import Foundation

public struct PathSafetyValidator: Sendable {
    public let homeDirectory: URL
    private let allowedPaths: Set<String>

    public init(homeDirectory: URL, allowedPaths: [String]) {
        self.homeDirectory = homeDirectory.standardizedFileURL
        self.allowedPaths = Set(allowedPaths.map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL.path
        })
    }

    public func isSafe(path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        let homePath = homeDirectory.path
        guard standardized == homePath || standardized.hasPrefix(homePath + "/") else {
            return false
        }

        return allowedPaths.contains(standardized)
    }
}
