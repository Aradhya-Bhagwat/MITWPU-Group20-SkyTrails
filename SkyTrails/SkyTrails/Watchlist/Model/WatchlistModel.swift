//
//  WatchlistModel.swift
//  SkyTrails
//
//  Created by SDC-USER on 13/02/26.
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Constants

enum WatchlistConstants {
    static let myWatchlistID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let defaultOwnerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

// MARK: - Enums

enum WatchlistType: String, Codable {
    case custom        // User-created with automation rules
    case shared        // Shared among multiple users
    case my_watchlist  // Virtual/derived - aggregation (Logic handled in Manager)
}

enum WatchlistEntryStatus: String, Codable {
    case to_observe
    case observed
}

enum WatchlistSharePermission: String, Codable {
    case view
    case edit
    case admin
}

enum WatchlistRuleType: String, Codable {
    case location
    case date_range
    case species_family
    case rarity_level
    case migration_pattern
}

enum WatchlistMode {
    case observed
    case unobserved
}

// MARK: - Core Watchlist Models

@Model
final class Watchlist {
    // Default owner ID for single-user offline mode
    static let defaultOwnerId = WatchlistConstants.defaultOwnerID
    
    @Attribute(.unique) var id: UUID
    var owner_id: UUID = Watchlist.defaultOwnerId // In a real app with Auth, this links to User
    var type: WatchlistType? // Default to custom if missing
    var title: String?
    var location: String?
    var lat: Double?  // Geocoded from location string
    var lon: Double?  // Geocoded from location string
    var startDate: Date?
    var endDate: Date?
    var observedCount: Int = 0
    var speciesCount: Int = 0
    var created_at: Date = Date()
    var updated_at: Date?
    var locationDisplayName: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \WatchlistEntry.watchlist) var entries: [WatchlistEntry]?
    @Relationship(deleteRule: .cascade, inverse: \WatchlistRule.watchlist) var rules: [WatchlistRule]?
    @Relationship(deleteRule: .cascade, inverse: \WatchlistShare.watchlist) var shares: [WatchlistShare]?
    @Relationship(deleteRule: .cascade, inverse: \WatchlistImage.watchlist) var images: [WatchlistImage]?
    
    init(
        id: UUID = UUID(),
        owner_id: UUID = Watchlist.defaultOwnerId,
        type: WatchlistType = .custom,
        title: String? = nil,
        location: String? = nil,
        locationDisplayName: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.id = id
        self.owner_id = owner_id
        self.type = type
        self.title = title
        self.location = location
        self.locationDisplayName = locationDisplayName
        self.startDate = startDate
        self.endDate = endDate
        self.created_at = Date()
    }
}

@Model
final class WatchlistEntry {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var bird: Bird? // Reference to the Bird Reference Data
    
    var nickname: String?
    var status: WatchlistEntryStatus
    var notes: String?
    var addedDate: Date = Date()
    var observationDate: Date?
    var toObserveStartDate: Date?
    var toObserveEndDate: Date?
    var observedBy: String? // Name of user who observed it (useful in shared lists)
    
    var was_auto_added: Bool = false  // Track if added by rules
    var source_rule_id: UUID?         // Which rule added it (if any)
    
    // Denormalized Location Data for Quick Access
    var lat: Double?
    var lon: Double?
    var locationDisplayName: String?
    
    var priority: Int = 0
    var notify_upcoming: Bool = false
    var target_date_range: String? // Text description like "Oct - Nov"
    
    @Relationship(deleteRule: .cascade, inverse: \ObservedBirdPhoto.watchlistEntry) var photos: [ObservedBirdPhoto]?
    
    init(
        id: UUID = UUID(),
        watchlist: Watchlist? = nil,
        bird: Bird? = nil,
        status: WatchlistEntryStatus = .to_observe,
        notes: String? = nil,
        observationDate: Date? = nil,
        observedBy: String? = nil
    ) {
        self.id = id
        self.watchlist = watchlist
        self.bird = bird
        self.status = status
        self.notes = notes
        self.observationDate = observationDate
        self.observedBy = observedBy
        self.addedDate = Date()
    }
}

@Model
final class WatchlistRule {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var rule_type: WatchlistRuleType
    var parameters_json: String // SwiftData doesn't support raw JSON types well, store as String
    var is_active: Bool = true
    var priority: Int = 0
    var created_at: Date = Date()
    
    // New fields for rules
    var radius_km: Double?           // For location rules (default 50)
    var families: [String]?          // For family rules ["Anatidae", "Laridae"]
    var shapes: [String]?            // For shape rules ["waterfowl", "raptor"]
    var manually_removed_bird_ids: [UUID]?  // Track manual removals
    
    init(id: UUID = UUID(), watchlist: Watchlist? = nil, rule_type: WatchlistRuleType, parameters: String) {
        self.id = id
        self.watchlist = watchlist
        self.rule_type = rule_type
        self.parameters_json = parameters
    }
}

@Model
final class WatchlistShare {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var user_id: UUID // The user it is shared WITH
    var permission: WatchlistSharePermission
    var shared_at: Date = Date()
    var shared_by_user_id: UUID?
    
    init(id: UUID = UUID(), watchlist: Watchlist? = nil, user_id: UUID, permission: WatchlistSharePermission = .view) {
        self.id = id
        self.watchlist = watchlist
        self.user_id = user_id
        self.permission = permission
    }
}

@Model
final class WatchlistImage {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var imagePath: String
    var uploaded_at: Date = Date()
    
    init(id: UUID = UUID(), watchlist: Watchlist? = nil, imagePath: String) {
        self.id = id
        self.watchlist = watchlist
        self.imagePath = imagePath
    }
}

@Model
final class ObservedBirdPhoto {
    @Attribute(.unique) var id: UUID
    var watchlistEntry: WatchlistEntry?
    var imagePath: String
    var captured_at: Date?
    var uploaded_at: Date = Date()
    
    init(id: UUID = UUID(), watchlistEntry: WatchlistEntry? = nil, imagePath: String) {
        self.id = id
        self.watchlistEntry = watchlistEntry
        self.imagePath = imagePath
    }
}

// MARK: - DTOs (Domain Models)

struct WatchlistSummaryDTO: Hashable {
    let id: UUID
    let title: String
    let subtitle: String // Location
    let dateText: String // "Oct - Nov"
    let image: String?
    let previewImages: [String] // For My Watchlist grid
    let stats: WatchlistStatsDTO
    let type: WatchlistType
}

struct WatchlistStatsDTO: Hashable {
    let observedCount: Int
    let totalCount: Int
    let rareCount: Int
}

// MARK: - Rule Parameter Models

// Replace existing LocationRuleParams with simplified version
struct LocationRuleParams: Codable {
    let radiusKm: Double
}

// Add new FamilyShapeRuleParams
struct FamilyShapeRuleParams: Codable {
    let families: [String]
    let shapes: [String]
}

struct DateRangeRuleParams: Codable {
    let startDate: Date
    let endDate: Date
}

struct SpeciesFamilyRuleParams: Codable {
    let families: [String] // e.g., ["Anatidae", "Laridae"]
}

struct RarityRuleParams: Codable {
    let levels: [String] // e.g., ["rare", "very_rare"]
}

struct MigrationPatternRuleParams: Codable {
    let strategies: [String] // e.g., ["long_distance", "altitudinal"]
    let hemisphere: String? // Optional: "northern" or "southern"
}

// MARK: - Rule Engine Extension

// Note: Extension is placed here because it depends on Rule Parameter Models above.
// It is kept in this file to consolidate all Watchlist-related model logic.
extension WatchlistManager {
    
    /// Apply all active rules to a watchlist and auto-add birds
    func applyRules(to watchlistId: UUID) async {
        print("🤖 [RuleEngine] Applying rules to watchlist \(watchlistId)")
        
        guard let watchlist = getWatchlist(by: watchlistId),
              let rules = watchlist.rules?.filter({ $0.is_active }) else {
            print("⚠️ [RuleEngine] No watchlist or no active rules")
            return
        }
        
        print("🤖 [RuleEngine] Found \(rules.count) active rules")
        
        var candidateBirds: Set<Bird> = []
        
        for rule in rules.sorted(by: { $0.priority > $1.priority }) {
            print("🔧 [RuleEngine] Processing rule: \(rule.rule_type.rawValue) (priority: \(rule.priority))")
            
            switch rule.rule_type {
            case .location:
                candidateBirds.formUnion(await applyLocationRule(rule))
            case .date_range:
                candidateBirds.formUnion(applyDateRangeRule(rule))
            case .species_family:
                candidateBirds.formUnion(applySpeciesFamilyRule(rule))
            case .rarity_level:
                candidateBirds.formUnion(applyRarityRule(rule))
            case .migration_pattern:
                candidateBirds.formUnion(applyMigrationRule(rule))
            }
        }
        
        print("🤖 [RuleEngine] Total candidate birds: \(candidateBirds.count)")
        
        // Add birds to watchlist (avoiding duplicates)
        if !candidateBirds.isEmpty {
            addBirds(Array(candidateBirds), to: watchlistId, asObserved: false)
        }
    }
    
    // MARK: - Individual Rule Processors
    
    private func applyLocationRule(_ rule: WatchlistRule) async -> Set<Bird> {
        print("📍 [RuleEngine] Applying location rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(LocationRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse location rule params")
            return []
        }
        
        let location = CLLocationCoordinate2D(latitude: params.latitude, longitude: params.longitude)
        let hotspotManager = HotspotManager(modelContext: context)
        
        var allBirds = Set<Bird>()
        
        if let weeks = params.weeks {
            // Specific weeks
            for week in weeks {
                let birds = hotspotManager.getBirdsPresent(
                    at: location,
                    duringWeek: week,
                    radiusInKm: params.radiusKm
                )
                allBirds.formUnion(birds)
            }
        } else {
            // All weeks (1-52)
            for week in 1...52 {
                let birds = hotspotManager.getBirdsPresent(
                    at: location,
                    duringWeek: week,
                    radiusInKm: params.radiusKm
                )
                allBirds.formUnion(birds)
            }
        }
        
        print("📍 [RuleEngine] Location rule found \(allBirds.count) birds")
        return allBirds
    }
    
    private func applyDateRangeRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("📅 [RuleEngine] Applying date range rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(DateRangeRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse date range rule params")
            return []
        }
        
        // Get calendar months from date range
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: params.startDate)
        let endMonth = calendar.component(.month, from: params.endDate)
        
        // Fetch all birds
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
        // Filter birds that are valid during this date range
        let validBirds = allBirds.filter { bird in
            guard let validMonths = bird.validMonths else { return false }
            
            // Check if any valid month falls in the range
            if startMonth <= endMonth {
                return validMonths.contains(where: { $0 >= startMonth && $0 <= endMonth })
            } else {
                // Range crosses year boundary
                return validMonths.contains(where: { $0 >= startMonth || $0 <= endMonth })
            }
        }
        
        print("📅 [RuleEngine] Date range rule found \(validBirds.count) birds")
        return Set(validBirds)
    }
    
    private func applySpeciesFamilyRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("🦆 [RuleEngine] Applying species family rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(SpeciesFamilyRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse species family rule params")
            return []
        }
        
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
        let matchingBirds = allBirds.filter { bird in
            guard let family = bird.family else { return false }
            return params.families.contains(family)
        }
        
        print("🦆 [RuleEngine] Species family rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    private func applyRarityRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("💎 [RuleEngine] Applying rarity rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(RarityRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse rarity rule params")
            return []
        }
        
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
        let matchingBirds = allBirds.filter { bird in
            guard let rarityLevel = bird.rarityLevel else { return false }
            return params.levels.contains(rarityLevel.rawValue)
        }
        
        print("💎 [RuleEngine] Rarity rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    private func applyMigrationRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("🛫 [RuleEngine] Applying migration pattern rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(MigrationPatternRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse migration pattern rule params")
            return []
        }
        
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
        let matchingBirds = allBirds.filter { bird in
            guard let strategy = bird.migration_strategy else { return false }
            
            let strategyMatches = params.strategies.contains(strategy)
            
            if let hemisphere = params.hemisphere {
                return strategyMatches && bird.hemisphere == hemisphere
            }
            
            return strategyMatches
        }
        
        print("🛫 [RuleEngine] Migration pattern rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    // MARK: - Rule Management
    
    /// Add a rule to a watchlist
    func addRule(
        to watchlistId: UUID,
        type: WatchlistRuleType,
        parameters: Encodable,
        priority: Int = 0
    ) throws {
        guard let watchlist = getWatchlist(by: watchlistId) else {
            throw RepositoryError.watchlistNotFound(watchlistId)
        }
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(parameters)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "WatchlistManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode parameters"])
        }
        
        let rule = WatchlistRule(
            watchlist: watchlist,
            rule_type: type,
            parameters: jsonString
        )
        rule.priority = priority
        
        context.insert(rule)
        saveContext()
        
        print("✅ [RuleEngine] Added \(type.rawValue) rule to watchlist")
    }
    
    /// Toggle rule active status
    func toggleRule(ruleId: UUID) {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == ruleId }
        )
        
        if let rule = try? context.fetch(descriptor).first {
            rule.is_active = !rule.is_active
            saveContext()
            print("🔧 [RuleEngine] Toggled rule \(ruleId) to \(rule.is_active ? "active" : "inactive")")
        }
    }
    
    /// Delete a rule
    func deleteRule(ruleId: UUID) {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == ruleId }
        )
        
        if let rule = try? context.fetch(descriptor).first {
            context.delete(rule)
            saveContext()
            print("🗑️ [RuleEngine] Deleted rule \(ruleId)")
        }
    }
}

// MARK: - Repository Protocol

protocol WatchlistRepository {
    func loadDashboardData() async throws -> (myWatchlist: WatchlistSummaryDTO?, custom: [WatchlistSummaryDTO], shared: [WatchlistSummaryDTO], globalStats: WatchlistStatsDTO)
    func deleteWatchlist(id: UUID) async throws
    func ensureMyWatchlistExists() async throws -> UUID
    func getPersonalWatchlists() -> [Watchlist]
}

// MARK: - User Preferences

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
            // Reverse geocode to get name
            homeLocationName = await LocationService.shared.reverseGeocode(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
        }
        
        print("🏠 [LocationPreferences] Home location set to: \(homeLocationName ?? "Unknown")")
    }
}
