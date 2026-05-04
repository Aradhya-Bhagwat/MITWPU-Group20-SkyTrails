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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use ONLY the anon key for public predictions to avoid 401 session issues
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["lat": lat, "lng": lng]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unauthorized or Server Error"
            print("DEBUG: API Error: \(errorMsg)")
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
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([HotspotModel].self, from: data)
    }

    func fetchGeoJSON(ebirdSpeciesCode: String, weekNumber: Int) async throws -> Data {
        let config = try SupabaseConfig.load()
        
        // Direct fetch from REST API for 'local' reliability during presentation
        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/species_ranges"
        components?.queryItems = [
            URLQueryItem(name: "ebird_species_code", value: "eq.\(ebirdSpeciesCode)"),
            URLQueryItem(name: "week_number", value: "eq.\(weekNumber)"),
            URLQueryItem(name: "select", value: "range_geojson")
        ]
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to fetch range from table")
        }

        struct RangeRecord: Codable {
            let range_geojson: String
        }

        let records = try JSONDecoder().decode([RangeRecord].self, from: data)
        guard let firstRecord = records.first,
              let geoData = firstRecord.range_geojson.data(using: .utf8) else {
            throw APIError.decodingError
        }
        return geoData
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
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let rows = try JSONDecoder().decode([RegionalTrendsRow].self, from: data)
        return rows.first?.species_data ?? []
    }
}
