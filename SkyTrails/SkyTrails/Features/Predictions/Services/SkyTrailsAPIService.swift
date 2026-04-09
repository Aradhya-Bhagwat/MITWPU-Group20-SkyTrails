import Foundation
import CoreLocation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case invalidResponse
    case decodingError(String)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The prediction service URL is invalid."
        case .unauthorized:
            return "The prediction service rejected the request."
        case .invalidResponse:
            return "The prediction service returned an invalid response."
        case .decodingError(let details):
            return "The prediction response format was unexpected. \(details)"
        case .serverError(_, let message):
            return message
        }
    }
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
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw APIError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Prediction service error."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode, errorMsg)
        }
        
        do {
            return try JSONDecoder().decode(HotspotPredictionResponse.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(Self.describeDecodingError(error))
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Failed to fetch hotspots.")
        }

        do {
            return try JSONDecoder().decode([HotspotModel].self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(Self.describeDecodingError(error))
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode, "Failed to fetch range from table")
        }

        struct RangeRecord: Codable {
            let range_geojson: String
        }

        let records: [RangeRecord]
        do {
            records = try JSONDecoder().decode([RangeRecord].self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(Self.describeDecodingError(error))
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
        guard let firstRecord = records.first,
              let geoData = firstRecord.range_geojson.data(using: .utf8) else {
            throw APIError.decodingError("Missing `range_geojson` in species range record.")
        }
        return geoData
    }

    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .keyNotFound(_, let context),
             .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "\(context.debugDescription) at \(path)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
