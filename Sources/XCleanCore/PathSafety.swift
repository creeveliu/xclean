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
        isSafe(path: path, allowingDescendantsOfAllowedPaths: false)
    }

    public func isSafe(path: String, allowingDescendantsOfAllowedPaths: Bool) -> Bool {
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        let homePath = homeDirectory.path
        guard standardized == homePath || standardized.hasPrefix(homePath + "/") else {
            return false
        }

        if allowedPaths.contains(standardized) {
            return true
        }

        guard allowingDescendantsOfAllowedPaths else {
            return false
        }

        return allowedPaths.contains { allowedPath in
            standardized.hasPrefix(allowedPath + "/")
        }
    }
}
