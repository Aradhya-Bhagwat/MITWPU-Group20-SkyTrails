
import Foundation

protocol NewsServiceProtocol: Sendable {
    func fetchNews() async -> [NewsItem]
}

/// Matches the single-row cache structure in Supabase: news_cache (id: 1, content: JSONB, last_updated: TIMESTAMPTZ)
private struct SupabaseNewsRow: Codable {
    let id: Int
    let content: [NewsItem]
    let last_updated: String
}

final class NewsService: NewsServiceProtocol {
    private let logger: LoggingServiceProtocol
    private let refreshInterval: TimeInterval = 60 * 60 // 1 hour
    private let cacheKey = "cached_news_items"
    private let lastFetchKey = "last_news_fetch_timestamp"
    private let maxNewsCount = 8
    
    init(logger: LoggingServiceProtocol = LoggingService.shared) {
        self.logger = logger
    }
    
    func fetchNews() async -> [NewsItem] {
        let cached = loadFromCache()
        let lastLocalFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let now = Date().timeIntervalSince1970
        
        // 1. If local cache is fresh (< 6h), return immediately
        if (now - lastLocalFetch) < refreshInterval && !cached.isEmpty {
            return Array(cached.prefix(maxNewsCount))
        }
        
        // 2. Local cache is stale or missing, fetch from Supabase
        do {
            if let supabaseData = try await fetchFromSupabaseTable() {
                if !supabaseData.content.isEmpty {
                    saveToCache(supabaseData.content)
                    return Array(supabaseData.content.prefix(maxNewsCount))
                }
            }
        } catch {
            logger.log(message: "Supabase news cache fetch failed: \(error.localizedDescription)", context: "NewsService")
        }

        // 3. Fallback: If Supabase fetch fails or is empty, use stale local cache as last resort
        return Array(cached.prefix(maxNewsCount))
    }
    
    private func fetchFromSupabaseTable() async throws -> SupabaseNewsRow? {
        // Fetch only from news_cache where id = 1
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
}
