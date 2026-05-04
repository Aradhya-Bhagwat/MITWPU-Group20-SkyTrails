import Foundation

struct GridHotspotItem: Decodable {
    let hotspot_id: String
    let name: String
    let lat: Double
    let lon: Double
    let checklist_count: Int
}

struct GridHotspotRow: Decodable {
    let grid_id: String
    let lat_sw: Double
    let lon_sw: Double
    let hotspots: [GridHotspotItem]
    let last_updated: String?
}

struct RegionalTrendSpeciesItem: Decodable {
    let id: String
    let name: String
    let max: Double
    let hits: Int
    let score: Double
}

struct RegionalTrendsRow: Decodable {
    let grid_id: String
    let week_number: Int
    let species_data: [RegionalTrendSpeciesItem]
    let last_updated: String?
}

func gridID(lat: Double, lon: Double) -> String {
    let gridLat = floor(lat / 0.5) * 0.5
    let gridLon = floor(lon / 0.5) * 0.5
    return String(format: "%.1f_%.1f", gridLat, gridLon)
}
