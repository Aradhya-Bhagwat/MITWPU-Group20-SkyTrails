
import Foundation
import CoreLocation



// Wrapper for 'home_data.json'
struct CoreHomeData: Codable {
    let predictedMigrations: [PredictedMigration]?
    let watchlistBirds: [UpcomingBird]?
    let recommendedBirds: [UpcomingBird]?
    let birdCategories: [BirdCategory]?
    let watchlistSpots: [PopularSpot]?
    let recommendedSpots: [PopularSpot]?
    let dynamicCards: [DynamicCard]?
    let communityObservations: [CommunityObservation]?
    let latestNews: [NewsItem]?
    let speciesData: [SpeciesData]?
}


// Wrapper for 'home_data.json' (News section)
struct NewsResponse: Codable {
    let latestNews: [NewsItem]?
}

// MARK: - 3. MODEL STRUCTS

// --- News Models ---
struct NewsItem: Codable {
    let title: String
    let description: String
    let summary: String
    let imageName: String
    let link: String
}
// ...
// (Keep existing structs)
// ...
// --- Community Models ---

struct CommunityObservation: Codable {
    let observationId: String?
    let username: String?
    let userAvatar: String?
    let observationTitle: String?
    let observationDescription: String?
    let observationImage: String?
    let location: String
    let timestamp: String?
    let likesCount: Int?
    let commentsCount: Int?
    
    // Legacy fields support (if JSON has old format, these might be populated)
    let user: User?
    let birdName: String?
    let imageName: String?
    
    // Compatibility Computed Properties
    var displayBirdName: String {
        return birdName ?? observationTitle ?? "Unknown Bird"
    }
    
    var displayImageName: String {
        return observationImage ?? imageName ?? ""
    }
    
    var displayUser: UserCompatibility {
        if let u = user {
            return UserCompatibility(name: u.name, observations: u.observations, profileImageName: u.profileImageName)
        }
        return UserCompatibility(name: username ?? "Unknown", observations: 0, profileImageName: userAvatar ?? "")
    }
}

struct UserCompatibility {
    let name: String
    let observations: Int
    let profileImageName: String
}


// ...
struct RawCoordinate: Codable {
    let lat: Double
    let lon: Double
}

struct RawHotspotPin: Codable {
    let lat: Double
    let lon: Double
    let birdImageName: String
}

struct PredictionInputData {
	var id: UUID = UUID()
	var locationName: String?
	var latitude: Double?
	var longitude: Double?
	var startDate: Date? = Date()
	var endDate: Date? = Date()
	var areaValue: Int = 2 // Default 2 km
	var weekRange: (start: Int, end: Int)? {
		guard let start = startDate, let end = endDate else { return nil }
		
		let startWeek = start.weekOfYear
		let endWeek = end.weekOfYear
		
		if startWeek > endWeek {
				// Handle wrap-around year change
			return (start: startWeek, end: endWeek + 52)
		}
		return (start: startWeek, end: endWeek)
	}
}

struct DynamicCard: Codable {
    let cardType: String
    
    // Migration Fields
    let birdName: String?
    let birdImageName: String?
    let startLocation: String?
    let endLocation: String?
    let currentProgress: Float?
    let migrationDateRange: String? // Match JSON key
    
    // Hotspot Fields
    let placeName: String?
    let speciesCount: Int?
    let placeImage: String?
    let distanceString: String?
    let areaBoundary: [RawCoordinate]?
    let hotspots: [RawHotspotPin]?
    let radius: Double?
    let hotspotDateRange: String? // Match JSON key
    
    // Remove the old 'let dateRange: String?' line entirely
}


// --- Clean Models for UI (Converted) ---

// Migration Card
struct MigrationPrediction {
    let birdName: String
    let birdImageName: String
    let startLocation: String
    let endLocation: String
    let dateRange: String
    let pathCoordinates: [CLLocationCoordinate2D]
    let currentProgress: Float
}

// Hotspot Sub-Model
struct BirdHotspot {
    let coordinate: CLLocationCoordinate2D
    let birdImageName: String
}

// Hotspot Card
struct HotspotPrediction {
    let placeName: String
    let placeImageName: String
    let speciesCount: Int
    let distanceString: String
    let dateRange: String
    let areaBoundary: [CLLocationCoordinate2D]
    let hotspots: [BirdHotspot]
    let radius: Double?
}

enum MapCardType {
    case combined(MigrationPrediction, HotspotPrediction)
}

// --- Home Section Models ---

struct PredictedMigration: Codable {
    let title: String
    let subtitle: String
    let imageName: String
}

struct UpcomingBird: Codable {
    let imageName: String
    let title: String
    let date: String
}

struct BirdCategory: Codable {
    let icon: String
    let title: String
}

struct PopularSpot: Codable {
	let imageName: String
	let title: String
	let location: String
	let latitude: Double?
	let longitude: Double?
	let radius: Double?
	let birds: [SpotBird]?
	var speciesCount: Int {
		return birds?.count ?? 0
	}
}
struct SpotBird: Codable {
    let name: String
    let imageName: String
    let lat: Double
    let lon: Double
}

// --- Community Models ---

struct User: Codable {
    let name: String
    let observations: Int
    let profileImageName: String
    

}





// MARK: - Prediction Models

struct PredictionDataWrapper: Codable {
    let speciesData: [SpeciesData]
}

struct SpeciesData: Codable {
    let id: String
    let name: String
    let imageName: String
    let sightings: [Sighting]
}

struct Sighting: Codable {
    let week: Int
    let lat: Double
    let lon: Double
    let locationName: String
}

// Helper for the Logic
// models.swift

// ... (All structs, extensions, and other classes remain the same)

// MARK: - Prediction Models (Continued)

struct FinalPredictionResult: Hashable { // Make it Hashable to easily get unique results
    let birdName: String
    let imageName: String
    let matchedInputIndex: Int
    let matchedLocation: (lat: Double, lon: Double)
    
    // Conform to Hashable for unique filtering
    func hash(into hasher: inout Hasher) {
        hasher.combine(birdName)
    }
    static func == (lhs: FinalPredictionResult, rhs: FinalPredictionResult) -> Bool {
        return lhs.birdName == rhs.birdName
    }
}


// Helper for the Logic
class PredictionEngine {
    static let shared = PredictionEngine()
    var allSpecies: [SpeciesData] = []
    
    init() {
        // Load data immediately
        if let speciesData = HomeManager.shared.predictionData?.speciesData {
            self.allSpecies = speciesData
        }
    }
    
    /// Finds all matching birds based on a single user input card's criteria.
   
}

// MARK: - 4. MAIN DATA MANAGER (HomeModels)

class HomeModels {
    
    // Data Arrays accessed by ViewController
    var predictedMigrations: [PredictedMigration] = []
    var watchlistBirds: [UpcomingBird] = []
    var recommendedBirds: [UpcomingBird] = []
    var birdCategories: [BirdCategory] = []
    var watchlistSpots: [PopularSpot] = []
    var recommendedSpots: [PopularSpot] = []

    var latestNews: [NewsItem] = []
    var communityObservations: [CommunityObservation] = []
	var dynamicCards: [DynamicCard] = []
    
	var homeScreenSpots: [PopularSpot] {
		if watchlistSpots.isEmpty {
			return recommendedSpots
		} else {
			return watchlistSpots
		}
	}
	var homeScreenBirds: [UpcomingBird] {
		if watchlistBirds.isEmpty {
			return recommendedBirds
		} else {
			return watchlistBirds
		}
	}
	
	
    init() {
			// 1. Load Core Home Data (from home_data.json)
		if let coreData = HomeManager.shared.coreHomeData {
			self.predictedMigrations = coreData.predictedMigrations ?? []
			self.watchlistBirds = coreData.watchlistBirds ?? []
			self.recommendedBirds = coreData.recommendedBirds ?? []
			self.birdCategories = coreData.birdCategories ?? []
			self.watchlistSpots = coreData.watchlistSpots ?? []
			self.recommendedSpots = coreData.recommendedSpots ?? []
			self.dynamicCards = coreData.dynamicCards ?? []
			self.communityObservations = coreData.communityObservations ?? []
		}
		
			// 3. Load News Data (from HomeManager -> home_data.json)
		if let newsData = HomeManager.shared.newsResponse {
			self.latestNews = newsData.latestNews ?? []
		}
    }
    

}

extension Date {
    /// Calculates the Gregorian calendar week number of the year for the date.
    var weekOfYear: Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: self)
    }
}


