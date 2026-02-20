import Foundation

struct SyncRetryPolicy {
    static let maxRetries: Int = 3
    static let initialDelay: TimeInterval = 1.0      // 1 second
    static let maxDelay: TimeInterval = 60.0         // 60 seconds
    static let backoffMultiplier: Double = 2.0       // Exponential backoff

    static func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(backoffMultiplier, Double(attempt))
        return min(delay, maxDelay)
    }

    static func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        if let urlError = error as? URLError {
            return urlError.code == .timedOut ||
                   urlError.code == .notConnectedToInternet ||
                   urlError.code == .networkConnectionLost
        }

        // By default, retry most errors until we hit max attempts.
        return true
    }
}

