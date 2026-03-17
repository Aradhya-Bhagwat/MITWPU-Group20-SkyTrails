
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
    private let defaultFallbackImage = "defaultProfile"
    private let defaultSourceName = "SkyTrails"
    
    // 6-hour refresh interval (4 times a day)
    private let refreshInterval: TimeInterval = 6 * 60 * 60 
    private let cacheKey = "cached_news_items"
    private let lastFetchKey = "last_news_fetch_timestamp"
    
    init(logger: LoggingServiceProtocol = LoggingService.shared) {
        self.logger = logger
    }
    
    func fetchNews() async -> [NewsItem] {
        // 1. Check local device cache first (Fastest)
        let cached = loadFromCache()
        let lastLocalFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let now = Date().timeIntervalSince1970
        
        if (now - lastLocalFetch) < refreshInterval && !cached.isEmpty {
            return cached
        }
        
        // 2. Try to fetch from Supabase Table (Global Cache)
        // This is cheaper than calling an Edge Function every time
        do {
            if let supabaseData = try await fetchFromSupabaseTable() {
                let lastUpdated = isoDate(from: supabaseData.last_updated) ?? Date(timeIntervalSince1970: 0)
                let supabaseAge = Date().timeIntervalSince(lastUpdated)
                
                // If the global cache is still fresh, use it
                if supabaseAge < refreshInterval && !supabaseData.content.isEmpty {
                    saveToCache(supabaseData.content)
                    return supabaseData.content
                }
            }
        } catch {
            logger.log(message: "Global cache fetch failed, attempting refresh...", context: "NewsService")
        }
        
        // 3. Global cache is stale or missing - Trigger the Edge Function
        // The Edge Function holds the API Key securely and updates the table
        do {
            let news = try await triggerEdgeFunctionRefresh()
            if !news.isEmpty {
                saveToCache(news)
                return news
            }
        } catch {
            logger.log(message: "Edge Function refresh failed: \(error.localizedDescription)", context: "NewsService")
        }
        
        // 4. Final fallback to whatever we have locally
        return cached
    }

    // MARK: - Supabase Integration
    
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
    
    private func triggerEdgeFunctionRefresh() async throws -> [NewsItem] {
        // This calls your Supabase Edge Function
        // The function should be named 'fetch-news'
        // It will use its internal Secret for NEWS_API_KEY
        return try await SupabaseClient.shared.post(
            path: "functions/v1/fetch-news",
            body: ["refresh": true], // Optional payload
            responseType: [NewsItem].self
        )
    }
    
    // MARK: - Local Caching Logic
    
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
