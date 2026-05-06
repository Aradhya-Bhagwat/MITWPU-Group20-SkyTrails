import Foundation
import CoreLocation

enum APIError: Error {
    case invalidURL
    case unauthorized
    case invalidResponse
    case decodingError
    case serverError(String)
}

final class SkyTrailsAPIService {
    static let shared = SkyTrailsAPIService()
    private init() {}
    
    /// Fetches predictions using the hybrid Edge Function (Live + Scientific Cache)
    func fetchPredictions(lat: Double, lng: Double) async throws -> HotspotPredictionResponse {
        let config = try SupabaseConfig.load()
        
        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/functions/v1/get-nearby-birds"
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use ONLY the anon key for public predictions to avoid 401 session issues
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["lat": lat, "lng": lng]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unauthorized or Server Error"
            throw APIError.serverError(errorMsg)
        }
        
        return try JSONDecoder().decode(HotspotPredictionResponse.self, from: data)
    }
    
    /// DIRECT FETCH: Gets locations directly from the Supabase 'hotspots_geo' table
    func fetchLocationsFromSupabase(near coordinate: CLLocationCoordinate2D) async throws -> [HotspotModel] {
        let config = try SupabaseConfig.load()
        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/hotspots_geo"
        // Simple bounding box or distance query could go here, for now we fetch all to verify connection
        components?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "10")
        ]
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([HotspotModel].self, from: data)
    }

    func fetchSpeciesRange(
        ebirdSpeciesCode: String,
        weekNumber: Int
    ) async throws -> String? {
        let config = try SupabaseConfig.load()
        let supabaseURL = config.projectURL.absoluteString
        let supabaseAnonKey = config.anonKey

        guard let url = URL(string: "\(supabaseURL)/functions/v1/fetch-species-range") 
        else { throw APIError.invalidURL }
        
        print("DEBUG RANGE: Full URL = \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", 
            forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "ebirdSpeciesCode": ebirdSpeciesCode,
            "weekNumber": weekNumber
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("DEBUG RANGE: HTTP status \(httpResponse.statusCode) for \(ebirdSpeciesCode) week \(weekNumber)")

        // 202 means no data for this week — not an error, just no range
        if httpResponse.statusCode == 202 {
            print("DEBUG RANGE: no range data for week \(weekNumber)")
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError("Status \(httpResponse.statusCode)")
        }

        struct RangeResponse: Decodable {
            let found: Bool
            let rangeGeoJSON: String?
        }

        let decoded = try JSONDecoder().decode(RangeResponse.self, from: data)

        guard decoded.found, let geoJSONString = decoded.rangeGeoJSON else {
            print("DEBUG RANGE: found=false or rangeGeoJSON nil")
            return nil
        }

        print("DEBUG RANGE: got GeoJSON string, length=\(geoJSONString.count)")
        return geoJSONString
    }

    func fetchGridHotspots(lat: Double, lon: Double) async throws -> GridHotspotRow? {
        let config = try SupabaseConfig.load()
        let gid = gridID(lat: lat, lon: lon)

        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/grid_hotspots"
        components?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "grid_id", value: "eq.\(gid)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let rows = try JSONDecoder().decode([GridHotspotRow].self, from: data)
        return rows.first
    }

    func fetchRegionalTrends(lat: Double, lon: Double, week: Int) async throws -> [RegionalTrendSpeciesItem] {
        let config = try SupabaseConfig.load()
        let gid = gridID(lat: lat, lon: lon)

        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/regional_trends"
        components?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "grid_id", value: "eq.\(gid)"),
            URLQueryItem(name: "week_number", value: "eq.\(week)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let rows = try JSONDecoder().decode([RegionalTrendsRow].self, from: data)
        return rows.first?.species_data ?? []
    }

    func fetchLiveHotspots(lat: Double, lon: Double, existingIds: [String]) async throws -> [LiveHotspotResult] {
        let config = try SupabaseConfig.load()
        
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.path = "/functions/v1/get-nearby-hotspots"
        
        guard let url = components.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "lat": lat,
            "lng": lon,
            "existingIds": existingIds,
            "dist": 40
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw APIError.serverError("get-nearby-hotspots failed")
        }
        
        let decoded = try JSONDecoder().decode(LiveHotspotsResponse.self, from: data)
        return decoded.hotspots
    }

    func fetchBirdImageUrls() async throws -> (
        speciesCodeMap: [String: String],
        scientificNameMap: [String: String],
        commonNameMap: [String: String]
    ) {
        let config = try SupabaseConfig.load()
        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/birds"
        components?.queryItems = [
            URLQueryItem(name: "select", value: "species_code,scientific_name,image_url,common_name"),
            URLQueryItem(name: "limit", value: "1000")
        ]
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to fetch bird image mapping")
        }
        
        struct BirdMapRow: Codable {
            let species_code: String?
            let scientific_name: String?
            let image_url: String?
            let common_name: String?
        }
        
        let rows = try JSONDecoder().decode([BirdMapRow].self, from: data)
        
        var speciesCodeMap: [String: String] = [:]
        var scientificNameMap: [String: String] = [:]
        var commonNameMap: [String: String] = [:]
        
        for row in rows {
            guard let url = row.image_url else { continue }
            
            if let common = row.common_name {
                commonNameMap[common] = url
            }
            if let code = row.species_code {
                speciesCodeMap[code] = url
            }
            if let sciName = row.scientific_name {
                scientificNameMap[sciName] = url
            }
        }
        
        return (speciesCodeMap, scientificNameMap, commonNameMap)
    }

}

struct LiveHotspotsResponse: Decodable {
    let hotspots: [LiveHotspotResult]
}

struct LiveHotspotResult: Decodable {
    let hotspotId: String
    let name: String
    let lat: Double
    let lon: Double
    let checklistCount: Int
    let distanceKm: Double
}
