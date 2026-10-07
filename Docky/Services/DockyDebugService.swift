//
//  DockyDebugService.swift
//  Docky
//
//  File-based debug logging plus layout-change reporting. Disabled by
//  default; flip it from Settings → Support → Debug or `docky.py debug`.
//  The logging gate reads UserDefaults live, so toggling takes effect
//  immediately without restarting Docky.
//

import AppKit
import Foundation
import OSLog

/// UserDefaults key. Lives outside `DockyPreferences` on purpose: the
/// service reads it live on every call, so CLI and Settings toggles
/// apply instantly with no restart and no observation plumbing.
enum DockyDebugLogging {
    static let enabledKey = "docky.debugLoggingEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}

final class DockyDebugService {
    static let shared = DockyDebugService()

    private static let logger = Logger(subsystem: "gt.quintero.Docky", category: "Debug")
    private static let maxLogBytes: UInt64 = 5 * 1024 * 1024

    private let queue = DispatchQueue(label: "docky.debug-log", qos: .utility)
    private var lastLayoutSignature: String?
    private var lastLayoutLogAt: Date = .distantPast

    private init() {}

    var logFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/Docky", directoryHint: .isDirectory)
        return dir.appending(path: "docky-debug.log", directoryHint: .notDirectory)
    }

    /// Appends a line to the log file (and mirrors to the unified log).
    /// No-op unless debug logging is enabled.
    func log(_ message: String, category: String = "debug") {
        guard DockyDebugLogging.isEnabled else { return }
        let line = "\(Self.timestamp()) [\(category)] \(message)\n"
        Self.logger.debug("\(message, privacy: .public)")
        queue.async { [logFileURL] in
            Self.append(line: line, to: logFileURL)
        }
    }

    /// Logs a layout report only when its signature changed (and at most
    /// once per second, so magnification hovers don't flood the file).
    func logLayoutIfChanged(signature: String, report: () -> String) {
        guard DockyDebugLogging.isEnabled else { return }
        let now = Date()
        guard signature != lastLayoutSignature,
              now.timeIntervalSince(lastLayoutLogAt) >= 1
        else { return }
        lastLayoutSignature = signature
        lastLayoutLogAt = now
        log(report(), category: "layout")
    }

    func clearLog() {
        try? FileManager.default.removeItem(at: logFileURL)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
    }

    // MARK: - Private

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private static func append(line: String, to url: URL) {
        let manager = FileManager.default
        try? manager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        rotateIfNeeded(url: url, manager: manager)
        guard let data = line.data(using: .utf8) else { return }
        if manager.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func rotateIfNeeded(url: URL, manager: FileManager) {
        guard let size = (try? manager.attributesOfItem(atPath: url.path)[.size]) as? UInt64,
              size > maxLogBytes
        else { return }
        let backup = url.appendingPathExtension("1")
        try? manager.removeItem(at: backup)
        try? manager.moveItem(at: url, to: backup)
    }
}
