import Foundation
import OSLog

/// Centralized logging facility writing to both the unified logging system and a rotating log file.
enum AppLogger {

    private static let subsystem = "com.woa.application"
    private static let osLog = Logger(subsystem: subsystem, category: "general")
    private static let maxLogFiles = 5
    private static let maxLogSizeBytes: UInt64 = 10 * 1024 * 1024
    private static let queue = DispatchQueue(label: "\(subsystem).logger")

    static func info(_ message: String) {
        osLog.info("\(message, privacy: .public)")
        write(level: "INFO", message: message)
    }

    static func warning(_ message: String) {
        osLog.warning("\(message, privacy: .public)")
        write(level: "WARNING", message: message)
    }

    static func error(_ message: String) {
        osLog.error("\(message, privacy: .public)")
        write(level: "ERROR", message: message)
    }

    private static func write(level: String, message: String) {
        queue.async {
            do {
                let fileURL = try AppPaths.logFileURL()
                try rotateIfNeeded(fileURL: fileURL)

                let timestamp = ISO8601DateFormatter().string(from: Date())
                let line = "\(timestamp) [\(level)] \(message)\n"
                guard let data = line.data(using: .utf8) else { return }

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: fileURL)
                }
            } catch {
                // Logging failures must never crash the app.
            }
        }
    }

    private static func rotateIfNeeded(fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? UInt64, size >= maxLogSizeBytes else { return }

        let directory = fileURL.deletingLastPathComponent()
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension

        // Shift existing rotated files up by one, dropping the oldest.
        for index in stride(from: maxLogFiles - 1, through: 1, by: -1) {
            let source = directory.appendingPathComponent("\(baseName).\(index).\(ext)")
            let destination = directory.appendingPathComponent("\(baseName).\(index + 1).\(ext)")
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            if FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.moveItem(at: source, to: destination)
            }
        }

        let firstRotated = directory.appendingPathComponent("\(baseName).1.\(ext)")
        if FileManager.default.fileExists(atPath: firstRotated.path) {
            try? FileManager.default.removeItem(at: firstRotated)
        }
        try FileManager.default.moveItem(at: fileURL, to: firstRotated)
    }
}
