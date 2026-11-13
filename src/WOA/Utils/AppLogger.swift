#if SWIFT_PACKAGE
enum AppLogger {
    static func info(_ message: String) {}
    static func warning(_ message: String) {}
    static func error(_ message: String) {}
    static func flush() {}
}
#else
import Foundation
import OSLog

/// Centralized logging facility writing to both the unified logging system and a rotating log file.
enum AppLogger {

    private static let subsystem = "com.woa.application"
    private static let osLog = Logger(subsystem: subsystem, category: "general")
    private static let maxLogFiles = 5
    private static let maxLogSizeBytes: UInt64 = 10 * 1024 * 1024
    private static let queue = DispatchQueue(label: "\(subsystem).logger")
    private static let formatter = ISO8601DateFormatter() // only touched on `queue`

    static func info(_ message: String) {
        osLog.info("\(message, privacy: .private)")
        write(level: "INFO", message: message)
    }

    static func warning(_ message: String) {
        osLog.warning("\(message, privacy: .private)")
        write(level: "WARNING", message: message)
    }

    static func error(_ message: String) {
        osLog.error("\(message, privacy: .private)")
        write(level: "ERROR", message: message)
    }

    /// Blocks until all queued log lines are written. Call before app termination.
    static func flush() {
        queue.sync {}
    }

    private static func write(level: String, message: String) {
        // Capture the time at call site, not when the queue gets to it.
        let date = Date()
        queue.async {
            do {
                let fileURL = try AppPaths.logFileURL()
                try rotateIfNeeded(fileURL: fileURL)

                let line = "\(formatter.string(from: date)) [\(level)] \(message)\n"
                let data = Data(line.utf8)

                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.synchronize()
            } catch {
                // Never crash, but don't fail silently either.
                NSLog("AppLogger write failed: \(error)")
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
#endif
