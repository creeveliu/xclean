import Foundation

public enum ByteFormatter {
    private static func makeFormatter() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }

    public static func string(for bytes: Int64?) -> String {
        guard let bytes else {
            return "n/a"
        }
        return makeFormatter().string(fromByteCount: bytes)
    }
}
