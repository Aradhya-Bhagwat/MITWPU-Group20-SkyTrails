import Foundation
import os

protocol LoggingServiceProtocol: Sendable {
    func log(error: Error, context: String)
    func log(message: String, context: String)
}

final class LoggingService: LoggingServiceProtocol {
    static let shared = LoggingService()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SkyTrails", category: "App")
    
    private init() {}
    
    func log(error: Error, context: String) {
        logger.error("❌ [\(context)] Error: \(error.localizedDescription) - Details: \(String(describing: error))")
    }
    
    func log(message: String, context: String) {
        logger.info("ℹ️ [\(context)] \(message)")
    }
}
