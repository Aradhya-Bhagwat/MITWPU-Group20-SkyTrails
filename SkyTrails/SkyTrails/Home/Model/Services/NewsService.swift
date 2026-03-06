
import Foundation

protocol NewsServiceProtocol: Sendable {
    func fetchNews() async -> [NewsItem]
}

final class NewsService: NewsServiceProtocol {
    private let logger: LoggingServiceProtocol
    private let defaultFallbackImage = "defaultProfile"
    private let defaultSourceName = "SkyTrails"
    
    init(logger: LoggingServiceProtocol = LoggingService.shared) {
        self.logger = logger
    }
    
    func fetchNews() async -> [NewsItem] {
        guard isAPIEnabled else {
            if useLocalJSON {
                logger.log(message: "BIRD_NEWS_ENABLE_API is OFF. Using local bundled news.", context: "NewsService")
                return Array(loadBundledNews().prefix(configuredMax))
            }

            logger.log(message: "BIRD_NEWS_ENABLE_API is OFF and BIRD_NEWS_USE_LOCAL_JSON is OFF. No news will be shown.", context: "NewsService")
            return []
        }

        if let apiKey = configuredAPIKey {
            do {
                let remote = try await fetchFromGNews(apiKey: apiKey)
                if !remote.isEmpty {
                    return Array(remote.prefix(configuredMax))
                }
                logger.log(message: "GNews returned no items. Falling back to local news.", context: "NewsService")
            } catch {
                logger.log(error: error, context: "NewsService")
                logger.log(message: "Falling back to local bundled news.", context: "NewsService")
            }
        } else {
            logger.log(message: "BIRD_NEWS_API_KEY missing. Using local bundled news.", context: "NewsService")
        }

        if useLocalJSON {
            return Array(loadBundledNews().prefix(configuredMax))
        }
        return []
    }

    private var isAPIEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "BIRD_NEWS_ENABLE_API") as? NSNumber)?.boolValue ?? false
    }

    private var configuredAPIKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "BIRD_NEWS_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty, !key.contains("YOUR_") else { return nil }
        return key
    }

    private var useLocalJSON: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "BIRD_NEWS_USE_LOCAL_JSON") as? NSNumber)?.boolValue ?? true
    }

    private var configuredQuery: String {
        let query = (Bundle.main.object(forInfoDictionaryKey: "BIRD_NEWS_QUERY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (query?.isEmpty == false) ? query! : "(birds OR avian OR ornithology OR migratory birds)"
    }

    private var configuredLang: String {
        let lang = (Bundle.main.object(forInfoDictionaryKey: "BIRD_NEWS_LANG") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (lang?.isEmpty == false) ? lang! : "en"
    }

    private var configuredMax: Int {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "BIRD_NEWS_MAX_RESULTS") as? NSNumber)?.intValue ?? 5
        return min(max(raw, 1), 5)
    }

    private func fetchFromGNews(apiKey: String) async throws -> [NewsItem] {
        guard var components = URLComponents(string: "https://gnews.io/api/v4/search") else {
            return []
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: configuredQuery),
            URLQueryItem(name: "lang", value: configuredLang),
            URLQueryItem(name: "sortby", value: "publishedAt"),
            URLQueryItem(name: "max", value: String(configuredMax)),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GNewsResponse.self, from: data)
        let mapped: [NewsItem] = decoded.articles.compactMap { article -> NewsItem? in
            guard let title = article.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                  let link = article.url?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else {
                return nil
            }

            let summary = article.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeSummary = (summary?.isEmpty == false) ? summary! : "Open to read the full bird news article."
            let image = article.image?.trimmingCharacters(in: .whitespacesAndNewlines)
            let source = article.source?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let publishedAt = article.publishedAt?.trimmingCharacters(in: .whitespacesAndNewlines)

            return NewsItem(
                title: title,
                summary: safeSummary,
                link: link,
                imageName: (image?.isEmpty == false) ? image! : defaultFallbackImage,
                sourceName: (source?.isEmpty == false) ? source! : defaultSourceName,
                publishedAt: (publishedAt?.isEmpty == false) ? publishedAt : nil
            )
        }

        return Array(mapped.prefix(configuredMax))
    }

    private func loadBundledNews() -> [NewsItem] {
        guard let url = Bundle.main.url(forResource: "home_data", withExtension: "json") else {
            logger.log(message: "Could not find home_data.json", context: "NewsService")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(LocalNewsEnvelope.self, from: data)
            return jsonData.latestNews ?? []
        } catch {
            logger.log(error: error, context: "NewsService")
            return []
        }
    }
}

private struct LocalNewsEnvelope: Decodable {
    let latestNews: [NewsItem]?
}

private struct GNewsResponse: Decodable {
    let articles: [GNewsArticle]
}

private struct GNewsArticle: Decodable {
    let title: String?
    let description: String?
    let url: String?
    let image: String?
    let publishedAt: String?
    let source: GNewsSource?
}

private struct GNewsSource: Decodable {
    let name: String?
}
