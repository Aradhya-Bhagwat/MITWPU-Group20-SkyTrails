
import Foundation
import CoreLocation

enum WatchlistConstants {
    static let myWatchlistID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let legacyDefaultOwnerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

final class LocationPreferences {
    static let shared = LocationPreferences()
    
    private let defaults = UserDefaults.standard
    private let homeLatKey = "kUserHomeLatitude"
    private let homeLonKey = "kUserHomeLongitude"
    private let homeNameKey = "kUserHomeLocationName"
    
    private init() {}
    
    var homeLocation: CLLocationCoordinate2D? {
        get {
            guard defaults.object(forKey: homeLatKey) != nil else { return nil }
            let lat = defaults.double(forKey: homeLatKey)
            let lon = defaults.double(forKey: homeLonKey)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            if let location = newValue {
                defaults.set(location.latitude, forKey: homeLatKey)
                defaults.set(location.longitude, forKey: homeLonKey)
            } else {
                defaults.removeObject(forKey: homeLatKey)
                defaults.removeObject(forKey: homeLonKey)
            }
        }
    }
    
    var homeLocationName: String? {
        get { defaults.string(forKey: homeNameKey) }
        set { defaults.set(newValue, forKey: homeNameKey) }
    }
    
    func setHomeLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) async {
        homeLocation = coordinate
        
        if let name = name {
            homeLocationName = name
        } else {
            homeLocationName = await LocationService.shared.reverseGeocode(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
        }
    }

    func clear() {
        homeLocation = nil
        homeLocationName = nil
    }
}

enum WatchlistIdentifier: Hashable {
    case custom(UUID)
    case shared(UUID)
    case virtual
    
    var uuid: UUID? {
        switch self {
        case .custom(let id), .shared(let id):
            return id
        case .virtual:
            return nil
        }
    }
    
    var isVirtual: Bool {
        if case .virtual = self { return true }
        return false
    }
    
    static func from(uuid: UUID, type: WatchlistType?) -> WatchlistIdentifier {
        if uuid == WatchlistConstants.myWatchlistID {
            return .virtual
        }
        
        switch type {
        case .custom:
            return .custom(uuid)
        case .shared:
            return .shared(uuid)
        case .my_watchlist, .none:
            return .virtual
        }
    }
}

struct WatchlistSummaryDTO: Hashable {
    let id: WatchlistIdentifier
    let title: String
    let subtitle: String
    let dateText: String
    let image: String?
    let previewImages: [String]
    let stats: WatchlistStatsDTO
    let type: WatchlistType
    var legacyUUID: UUID {
        switch id {
        case .custom(let uuid), .shared(let uuid):
            return uuid
        case .virtual:
            return WatchlistConstants.myWatchlistID
        }
    }
}

struct WatchlistStatsDTO: Hashable {
    let observedCount: Int
    let totalCount: Int
    let rareCount: Int
    
    var progressPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(observedCount) / Double(totalCount) * 100
    }
    
    static let empty = WatchlistStatsDTO(observedCount: 0, totalCount: 0, rareCount: 0)
}

struct WatchlistDetailDTO {
    let id: WatchlistIdentifier
    let title: String
    let location: String?
    let locationDisplayName: String?
    let dateRange: String?
    let stats: WatchlistStatsDTO
    let type: WatchlistType
    let images: [String]
    let rules: [WatchlistRuleDTO]
    let isVirtual: Bool
}

struct WatchlistEntryDTO: Hashable {
    let id: UUID
    let watchlistID: WatchlistIdentifier
    let bird: BirdReferenceDTO
    let status: WatchlistEntryStatus
    let notes: String?
    let addedDate: Date
    let observationDate: Date?
    let toObserveStartDate: Date?
    let toObserveEndDate: Date?
    let observedBy: String?
    let observedByUserId: UUID?
    let location: LocationDTO?
    let photos: [String]
    let priority: Int
    let notifyUpcoming: Bool
    
    var isObserved: Bool { status == .observed }
    var displayDateRange: String {
        if let start = toObserveStartDate, let end = toObserveEndDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        return "Season pending"
    }
}

struct BirdReferenceDTO: Hashable {
    let id: UUID
    let commonName: String
    let scientificName: String?
    let staticImageName: String
    let family: String?
    
    var displayName: String {
        commonName
    }
}

struct LocationDTO: Hashable {
    let latitude: Double
    let longitude: Double
    let displayName: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct WatchlistRuleDTO: Hashable {
    let id: UUID
    let type: WatchlistRuleType
    let parameters: RuleParameters
    let isActive: Bool
    let priority: Int
    
    var displayDescription: String {
        switch parameters {
        case .location(let params):
            return "Within \(params.radiusKm)km of selected location"
        case .dateRange(let params):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Between \(formatter.string(from: params.startDate)) and \(formatter.string(from: params.endDate))"
        case .speciesFamily(let params):
            return "Shape: \(params.shapeId)"
        case .migration(let params):
            return "Migration pattern: \(params.patternKey)"
        }
    }
}

enum RuleParameters: Hashable {
    case location(LocationRuleParams)
    case dateRange(DateRangeRuleParams)
    case speciesFamily(SpeciesFamilyRuleParams)
    case migration(MigrationPatternRuleParams)
    
    static func from(rule: WatchlistRule) -> RuleParameters? {
        switch rule.rule_type {
        case .location:
            guard let lat = rule.lat,
                  let lon = rule.lon,
                  let radiusKm = rule.radius_km
            else { return nil }
            return .location(LocationRuleParams(lat: lat, lon: lon, radiusKm: radiusKm))
            
        case .date_range:
            guard let startDate = rule.start_date,
                  let endDate = rule.end_date
            else { return nil }
            return .dateRange(DateRangeRuleParams(startDate: startDate, endDate: endDate))
            
        case .species_family:
            guard let shapeId = rule.shape_id else { return nil }
            return .speciesFamily(SpeciesFamilyRuleParams(shapeId: shapeId))
            
        case .migration_pattern:
            guard let patternKey = rule.pattern_key else { return nil }
            return .migration(MigrationPatternRuleParams(patternKey: patternKey))
        }
    }
    
    func apply(to rule: WatchlistRule) {
        rule.lat = nil
        rule.lon = nil
        rule.radius_km = nil
        rule.start_date = nil
        rule.end_date = nil
        rule.shape_id = nil
        rule.pattern_key = nil
        
        switch self {
        case .location(let params):
            rule.lat = params.lat
            rule.lon = params.lon
            rule.radius_km = params.radiusKm
        case .dateRange(let params):
            rule.start_date = params.startDate
            rule.end_date = params.endDate
        case .speciesFamily(let params):
            rule.shape_id = params.shapeId
        case .migration(let params):
            rule.pattern_key = params.patternKey
        }
    }
}

struct LocationRuleParams: Codable, Hashable {
    let lat: Double
    let lon: Double
    let radiusKm: Double
}

struct DateRangeRuleParams: Codable, Hashable {
    let startDate: Date
    let endDate: Date
}

struct SpeciesFamilyRuleParams: Codable, Hashable {
    let shapeId: String
}

struct MigrationPatternRuleParams: Codable, Hashable {
    let patternKey: String
}

struct WatchlistQueryFilter {
    var status: WatchlistEntryStatus?
    var searchText: String?
    var families: [String]?
    var hasPhotos: Bool?
    var dateRange: (start: Date, end: Date)?
    
    nonisolated init(
        status: WatchlistEntryStatus? = nil,
        searchText: String? = nil,
        families: [String]? = nil,
        hasPhotos: Bool? = nil,
        dateRange: (start: Date, end: Date)? = nil
    ) {
        self.status = status
        self.searchText = searchText
        self.families = families
        self.hasPhotos = hasPhotos
        self.dateRange = dateRange
    }
    
    static let none = WatchlistQueryFilter()
}

enum WatchlistSortOption {
    case addedDateNewest
    case addedDateOldest
    case birdNameAZ
    case birdNameZA
    case observationDateNewest
    case observationDateOldest
    case priority
    
    var displayName: String {
        switch self {
        case .addedDateNewest: return "Recently Added"
        case .addedDateOldest: return "First Added"
        case .birdNameAZ: return "Name (A-Z)"
        case .birdNameZA: return "Name (Z-A)"
        case .observationDateNewest: return "Recently Observed"
        case .observationDateOldest: return "First Observed"
        case .priority: return "Priority"
        }
    }
}

struct WatchlistOperationResult {
    let success: Bool
    let watchlistID: WatchlistIdentifier?
    let error: WatchlistError?
    
    static func success(_ id: WatchlistIdentifier) -> WatchlistOperationResult {
        WatchlistOperationResult(success: true, watchlistID: id, error: nil)
    }
    
    static func failure(_ error: WatchlistError) -> WatchlistOperationResult {
        WatchlistOperationResult(success: false, watchlistID: nil, error: error)
    }
}

struct EntryOperationResult {
    let success: Bool
    let entryID: UUID?
    let error: WatchlistError?
    
    static func success(_ id: UUID) -> EntryOperationResult {
        EntryOperationResult(success: true, entryID: id, error: nil)
    }
    
    static func failure(_ error: WatchlistError) -> EntryOperationResult {
        EntryOperationResult(success: false, entryID: nil, error: error)
    }
}

protocol WatchlistRepository {
    func loadDashboardData() async throws -> (
        myWatchlist: WatchlistSummaryDTO?,
        custom: [WatchlistSummaryDTO],
        shared: [WatchlistSummaryDTO],
        globalStats: WatchlistStatsDTO
    )
    func deleteWatchlist(id: UUID) async throws
    func ensureMyWatchlistExists() async throws -> UUID
    func getPersonalWatchlists() -> [Watchlist]
}

enum WatchlistError: Error, LocalizedError {
    case watchlistNotFound(WatchlistIdentifier)
    case entryNotFound(UUID)
    case birdNotFound(UUID)
    case duplicateEntry(birdName: String)
    case persistenceFailed(underlying: Error)
    case ruleValidationFailed(String)
    case photoAttachmentFailed(underlying: Error)
    case invalidVirtualOperation(String)
    case invalidDateRange
    case locationServiceUnavailable
    case noMatchingWatchlists
    
    var errorDescription: String? {
        switch self {
        case .watchlistNotFound(let id):
            return "Watchlist not found: \(id)"
        case .entryNotFound(let id):
            return "Entry not found: \(id)"
        case .birdNotFound(let id):
            return "Bird not found: \(id)"
        case .duplicateEntry(let name):
            return "\(name) is already in this watchlist"
        case .persistenceFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .ruleValidationFailed(let message):
            return "Rule validation failed: \(message)"
        case .photoAttachmentFailed(let error):
            return "Failed to attach photo: \(error.localizedDescription)"
        case .invalidVirtualOperation(let message):
            return "Cannot perform this operation on virtual watchlist: \(message)"
        case .invalidDateRange:
            return "End date must be after start date"
        case .locationServiceUnavailable:
            return "Location services are unavailable"
        case .noMatchingWatchlists:
            return "Bird could not find any matching watchlists"
        }
    }
}
