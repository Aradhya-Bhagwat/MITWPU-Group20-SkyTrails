//
//  NewsService.swift
//  SkyTrails
//
//  Created by Gemini CLI on 16/02/2026.
//

import Foundation

protocol NewsServiceProtocol: Sendable {
    func fetchNews() async -> [NewsItem]
}

final class NewsService: NewsServiceProtocol {
    private let logger: LoggingServiceProtocol
    
    init(logger: LoggingServiceProtocol = LoggingService.shared) {
        self.logger = logger
    }
    
    func fetchNews() async -> [NewsItem] {
        guard let url = Bundle.main.url(forResource: "home_data", withExtension: "json") else {
            logger.log(message: "Could not find home_data.json", context: "NewsService")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(HomeJSONData.self, from: data)
            return jsonData.latestNews ?? []
        } catch {
            logger.log(error: error, context: "NewsService")
            return []
        }
    }
}
