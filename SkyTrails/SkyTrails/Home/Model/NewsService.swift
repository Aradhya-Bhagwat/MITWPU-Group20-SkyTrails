
import Foundation

protocol NewsServiceProtocol: Sendable {
    func fetchNews() async -> [NewsItem]
}

struct SupabaseNewsRow: Codable {
    let id: Int
    let content: [NewsItem]
    let last_updated: String
}

final class NewsService: NewsServiceProtocol {
    private let logger: LoggingServiceProtocol
    private let refreshInterval: TimeInterval = 6 * 60 * 60
    private let cacheKey = "cached_news_items"
    private let lastFetchKey = "last_news_fetch_timestamp"
    private let maxNewsCount = 5
    
    init(logger: LoggingServiceProtocol = LoggingService.shared) {
        self.logger = logger
    }
    
    func fetchNews() async -> [NewsItem] {
        let cached = loadFromCache()
        let lastLocalFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let now = Date().timeIntervalSince1970
        
        if (now - lastLocalFetch) < refreshInterval && !cached.isEmpty {
            return Array(cached.prefix(maxNewsCount))
        }
        
        do {
            if let supabaseData = try await fetchFromSupabaseTable() {
                let lastUpdated = isoDate(from: supabaseData.last_updated) ?? Date(timeIntervalSince1970: 0)
                let supabaseAge = Date().timeIntervalSince(lastUpdated)
                
                if supabaseAge < refreshInterval && !supabaseData.content.isEmpty {
                    saveToCache(supabaseData.content)
                    return Array(supabaseData.content.prefix(maxNewsCount))
                }

                if !supabaseData.content.isEmpty {
                    saveToCache(supabaseData.content)
                    return Array(supabaseData.content.prefix(maxNewsCount))
                }
            }
        } catch {
            logger.log(message: "Supabase news cache fetch failed: \(error.localizedDescription)", context: "NewsService")
        }

        if !cached.isEmpty {
            return Array(cached.prefix(maxNewsCount))
        }
        return []
    }
    
    private func fetchFromSupabaseTable() async throws -> SupabaseNewsRow? {
        let rows: [SupabaseNewsRow] = try await SupabaseClient.shared.get(
            path: "rest/v1/news_cache",
            options: SupabaseRequestOptions(queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.1"),
                URLQueryItem(name: "limit", value: "1")
            ])
        )
        return rows.first
    }
    
    private func saveToCache(_ news: [NewsItem]) {
        do {
            let data = try JSONEncoder().encode(news)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
        } catch {
            logger.log(error: error, context: "NewsService")
        }
    }
    
    private func loadFromCache() -> [NewsItem] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return [] }
        do {
            return try JSONDecoder().decode([NewsItem].self, from: data)
        } catch {
            logger.log(error: error, context: "NewsService")
            return []
        }
    }
    
    private func isoDate(from raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}
