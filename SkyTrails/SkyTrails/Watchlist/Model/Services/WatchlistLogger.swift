import Foundation
import os.log

// MARK: - Structured Logger for Watchlist Module

enum WatchlistLog {
    
    private static let subsystem = "com.skytrails.watchlist"
    
    private static let subsystemLog = OSLog(subsystem: subsystem, category: "general")
    private static let errorLog = OSLog(subsystem: subsystem, category: "error")
    private static let syncLog = OSLog(subsystem: subsystem, category: "sync")
    private static let uiLog = OSLog(subsystem: subsystem, category: "ui")
    
    // MARK: - Public API
    
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileContext = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let errorInfo = error.map { " | Error: \($0.localizedDescription)" } ?? ""
        os_log("[ERROR] %{public}@:%{public}@:%{public}d - %{public}@%{public}@", log: errorLog, type: .error, fileContext, function, line, message, errorInfo)
    }
    
    static func warn(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileContext = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        os_log("[WARN] %{public}@:%{public}@:%{public}d - %{public}@", log: subsystemLog, type: .default, fileContext, function, line, message)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileContext = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        os_log("[INFO] %{public}@:%{public}@:%{public}d - %{public}@", log: subsystemLog, type: .info, fileContext, function, line, message)
        #endif
    }
    
    static func sync(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileContext = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        os_log("[SYNC] %{public}@:%{public}@:%{public}d - %{public}@", log: syncLog, type: .info, fileContext, function, line, message)
        #endif
    }
    
    static func ui(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileContext = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        os_log("[UI] %{public}@:%{public}@:%{public}d - %{public}@", log: uiLog, type: .info, fileContext, function, line, message)
        #endif
    }
    
    // MARK: - Safe execution helpers
    
    @discardableResult
    static func safe<T>(_ operation: () throws -> T, or defaultValue: T, message: String? = nil, file: String = #file, function: String = #function, line: Int = #line) -> T {
        do {
            return try operation()
        } catch {
            WatchlistLog.error(message ?? "Operation failed", error: error, file: file, function: function, line: line)
            return defaultValue
        }
    }
    
    @discardableResult
    static func safe<T>(_ operation: () throws -> T, message: String? = nil, file: String = #file, function: String = #function, line: Int = #line) -> T? {
        do {
            return try operation()
        } catch {
            WatchlistLog.error(message ?? "Operation failed", error: error, file: file, function: function, line: line)
            return nil
        }
    }
    
    static func safeAsync(_ operation: @escaping () async throws -> Void, message: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        Task {
            do {
                try await operation()
            } catch {
                WatchlistLog.error(message ?? "Async operation failed", error: error, file: file, function: function, line: line)
            }
        }
    }
}
