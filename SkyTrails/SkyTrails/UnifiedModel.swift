
import Foundation
import CoreLocation

/// A unified representation of all models within the SkyTrails application.
/// This file aggregates models from Home, Identification, Watchlist, and Shared modules.
/// It uses a namespaced approach to prevent conflicts with the existing global types.
enum UnifiedModel {

    // MARK: - Shared Domain
    
    enum Shared {
        
        enum Rarity: String, Codable {
            case rare
            case common
        }

        struct Bird: Codable {
            var id: UUID = UUID()
            var name: String
            let scientificName: String
            var images: [String]
            var rarity: [Rarity]
            var location: [String]
            var date: [Date]
            var observedBy: [String]?
            var notes: String?
        }
        
		struct User: Identifiable, Codable, Hashable {
			let id: UUID
			var username: String
			var fullName: String
			var email: String
			var avatarURL: URL?
			var bio: String?
			var isVerified: Bool
			var role: UserRole
			var dateJoined: Date
			
				// Nested enum for User permissions/types
			enum UserRole: String, Codable, CaseIterable {
				case admin
				case member
				case guest
			}
			
				// Computed property for initials (Great for generic avatars)
			var initials: String {
				let components = fullName.components(separatedBy: " ")
				let first = components.first?.first
				let last = components.last?.first
				return "\(first ?? "?")\(last ?? "?")".uppercased()
			}
		}
    }

    // MARK: - Home Domain
    
    enum Home {
        
        // MARK: API Response Wrappers
        struct CoreHomeData: Codable {
            let predicted_migrations: [PredictedMigration]?
            let watchlist_birds: [UpcomingBird]?
            let recommended_birds: [UpcomingBird]?
            let bird_categories: [BirdCategory]?
            let watchlist_spots: [PopularSpot]?
            let recommended_spots: [PopularSpot]?
            let dynamic_predictions: [DynamicCard]?
            let community_observations: [CommunityObservation]?
        }

        struct NewsResponse: Codable {
            let latest_news: [NewsItem]?
        }
        
        // MARK: Models
        struct NewsItem: Codable {
            let title: String
            let description: String
            let summary: String
            let imageName: String
            let link: String
        }

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
            
            // Legacy/Compatibility
            let user: Shared.User?
            let birdName: String?
            let imageName: String?
            
            // Note: Computed properties like `displayBirdName` are logic, omitted from pure model struct for clarity
        }

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
        }

        struct SpotBird: Codable {
            let name: String
            let imageName: String
            let lat: Double
            let lon: Double
        }
        
        struct DynamicCard: Codable {
            let card_type: String
            // Migration Fields
            let bird_name: String?
            let bird_image_name: String?
            let start_location: String?
            let end_location: String?
            let current_progress: Float?
            let path_points: [RawCoordinate]?
            // Hotspot Fields
            let place_name: String?
            let species_count: Int?
            let place_image: String?
            let distance_string: String?
            let area_boundary: [RawCoordinate]?
            let hotspots: [RawHotspotPin]?
            let radius: Double?
            let date_range: String?
        }
        
        struct RawCoordinate: Codable {
            let lat: Double
            let lon: Double
        }

        struct RawHotspotPin: Codable {
            let lat: Double
            let lon: Double
            let bird_image_name: String
        }
    }

    // MARK: - Prediction Domain
    
    enum Prediction {
        
        struct InputData {
            var id: UUID = UUID()
            var locationName: String?
            var latitude: Double?
            var longitude: Double?
            var startDate: Date? = Date()
            var endDate: Date? = Date()
            var areaValue: Int = 2
        }
        
        struct DataWrapper: Codable {
            let species_data: [SpeciesData]
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
        
        struct FinalResult: Hashable {
            let birdName: String
            let imageName: String
            let matchedInputIndex: Int
            let matchedLocation: (lat: Double, lon: Double)
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(birdName)
            }
            static func == (lhs: FinalResult, rhs: FinalResult) -> Bool {
                return lhs.birdName == rhs.birdName
            }
        }
        
        // Clean Models for UI
        struct MigrationPrediction {
            let birdName: String
            let birdImageName: String
            let startLocation: String
            let endLocation: String
            let dateRange: String
            let pathCoordinates: [CLLocationCoordinate2D]
            let currentProgress: Float
        }

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
        
        struct BirdHotspot {
            let coordinate: CLLocationCoordinate2D
            let birdImageName: String
        }
    }

    // MARK: - Identification Domain
    
    enum Identification {
        
        struct Data {
            var date: String?
            var location: String?
            var size: String?
            var shape: String?
            var fieldMarks: [String]?
        }
        
        struct BirdDatabase: Codable {
            var birds: [ReferenceBird]
            let reference_data: ReferenceData
            
            enum CodingKeys: String, CodingKey {
                case birds
                case reference_data
            }
        }

        struct ReferenceData: Codable {
            let shapes: [BirdShape]
            let fieldMarks: [ReferenceFieldMark]
            
            enum CodingKeys: String, CodingKey {
                case shapes
                case fieldMarks = "field_marks"
            }
        }

        struct ReferenceFieldMark: Codable {
            let area: String
            let variants: [String]
        }

        struct BirdShape: Codable {
            let id: String
            let name: String
            let icon: String
            var imageView: String { return icon }
        }

        struct ReferenceBird: Codable, Identifiable {
            let id: String
            let commonName: String
            let scientificName: String?
            let imageName: String
            let validLocations: [String]
            let validMonths: [Int]?
            let attributes: BirdAttributes
            let fieldMarks: [FieldMarkData]
            var isUserCreated: Bool? = false
            
            enum CodingKeys: String, CodingKey {
                case id, attributes, isUserCreated
                case commonName = "common_name"
                case scientificName = "scientific_name"
                case imageName = "image_name"
                case validLocations = "valid_locations"
                case validMonths = "valid_months"
                case fieldMarks = "field_marks"
            }
        }

        struct BirdAttributes: Codable {
            let shapeId: String
            let sizeCategory: Int
            let rarity: String
            
            enum CodingKeys: String, CodingKey {
                case shapeId = "shape_id"
                case sizeCategory = "size_category"
                case rarity
            }
        }

        struct FieldMarkData: Codable {
            let area: String
            let variant: String
            let colors: [String]
        }

        struct History: Codable {
            var imageView: String
            var specieName: String
            var date: String
        }
        
        struct IdentificationBird: Codable, Identifiable {
            let id: String
            let name: String
            let scientificName: String
            let confidence: Double
            let description: String
            let imageName: String
            let scoreBreakdown: String
        }
    }

    // MARK: - Watchlist Domain
    
    enum Watchlist {
        
        enum Mode {
            case observed
            case unobserved
            case create
        }

        struct List: Codable {
            let id: UUID
            var title: String
            var location: String
            var startDate: Date
            var endDate: Date
            
            var observedBirds: [Shared.Bird]
            var toObserveBirds: [Shared.Bird]
            
            var birds: [Shared.Bird] {
                return observedBirds + toObserveBirds
            }
            
            var observedCount: Int {
                return observedBirds.count
            }
        }

        struct SharedStats: Codable {
            var greenValue: Int
            var blueValue: Int
        }

        struct SharedList: Codable {
            let id: UUID
            var title: String
            var location: String
            var dateRange: String
            var mainImageName: String
            var stats: SharedStats
            var userImages: [String]
            
            var observedBirds: [Shared.Bird] = []
            var toObserveBirds: [Shared.Bird] = []
            
            var birds: [Shared.Bird] {
                return observedBirds + toObserveBirds
            }
        }
    }
}
