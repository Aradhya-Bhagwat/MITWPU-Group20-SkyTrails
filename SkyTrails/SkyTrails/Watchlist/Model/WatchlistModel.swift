//
//  WatchlistModel.swift
//  SkyTrails
//
//  Created by SDC-USER on 13/02/26.
//

import Foundation
import SwiftData
import CoreLocation

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

// MARK: - Entity to Domain Model Transformations

extension Watchlist {
    /// Convert persistence entity to domain DTO
    func toDomain() -> WatchlistDetailDTO {
        let identifier = WatchlistIdentifier.from(uuid: self.id, type: self.type)
        
        let dateRange: String?
        if let start = self.startDate, let end = self.endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            dateRange = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            dateRange = nil
        }
        
        let stats = WatchlistStatsDTO(
            observedCount: self.observedCount,
            totalCount: self.speciesCount,
            rareCount: self.entries?.filter { $0.bird?.rarityLevel?.rawValue == "rare" || $0.bird?.rarityLevel?.rawValue == "very_rare" }.count ?? 0
        )
        
        return WatchlistDetailDTO(
            id: identifier,
            title: self.title ?? "Unnamed Watchlist",
            location: self.location,
            locationDisplayName: self.locationDisplayName,
            dateRange: dateRange,
            stats: stats,
            type: self.type ?? .custom,
            images: self.images?.compactMap { $0.imagePath } ?? [],
            rules: self.rules?.map { $0.toDomain() } ?? [],
            isVirtual: identifier.isVirtual
        )
    }
    
    /// Convert persistence entity to summary DTO
    func toSummary(previewImages: [String] = []) -> WatchlistSummaryDTO {
        let identifier = WatchlistIdentifier.from(uuid: self.id, type: self.type)
        
        let subtitle = self.locationDisplayName ?? self.location ?? "No location"
        
        let dateText: String
        if let start = self.startDate, let end = self.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            dateText = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            dateText = "Season pending"
        }
        
        let stats = WatchlistStatsDTO(
            observedCount: self.observedCount,
            totalCount: self.speciesCount,
            rareCount: self.entries?.filter { $0.bird?.rarityLevel?.rawValue == "rare" || $0.bird?.rarityLevel?.rawValue == "very_rare" }.count ?? 0
        )
        
        return WatchlistSummaryDTO(
            id: identifier,
            title: self.title ?? "Unnamed Watchlist",
            subtitle: subtitle,
            dateText: dateText,
            image: self.images?.first?.imagePath,
            previewImages: previewImages,
            stats: stats,
            type: self.type ?? .custom
        )
    }
}

extension WatchlistEntry {
    /// Convert persistence entity to domain DTO
    func toDomain() -> WatchlistEntryDTO? {
        guard let bird = self.bird else { return nil }
        guard let watchlist = self.watchlist else { return nil }
        
        let watchlistID = WatchlistIdentifier.from(uuid: watchlist.id, type: watchlist.type)
        
        let location: LocationDTO?
        if let lat = self.lat, let lon = self.lon {
            location = LocationDTO(
                latitude: lat,
                longitude: lon,
                displayName: self.locationDisplayName
            )
        } else {
            location = nil
        }
        
        return WatchlistEntryDTO(
            id: self.id,
            watchlistID: watchlistID,
            bird: bird.toReference(),
            status: self.status,
            notes: self.notes,
            addedDate: self.addedDate,
            observationDate: self.observationDate,
            toObserveStartDate: self.toObserveStartDate,
            toObserveEndDate: self.toObserveEndDate,
            observedBy: self.observedBy,
            location: location,
            photos: self.photos?.compactMap { $0.imagePath } ?? [],
            priority: self.priority,
            notifyUpcoming: self.notify_upcoming,
            targetDateRange: self.target_date_range
        )
    }
}

extension WatchlistRule {
    /// Convert persistence entity to domain DTO
    func toDomain() -> WatchlistRuleDTO {
        let params = RuleParameters.from(type: self.rule_type, json: self.parameters_json) 
            ?? .location(LocationRuleParams(lat: 0, lon: 0, radiusKm: 0, validWeeks: nil))
        
        return WatchlistRuleDTO(
            id: self.id,
            type: self.rule_type,
            parameters: params,
            isActive: self.is_active,
            priority: self.priority
        )
    }
}

extension Bird {
    /// Convert Bird entity to reference DTO for use in watchlist entries
    func toReference() -> BirdReferenceDTO {
        BirdReferenceDTO(
            id: self.id,
            commonName: self.commonName,
            scientificName: self.scientificName,
            staticImageName: self.staticImageName,
            rarityLevel: self.rarityLevel.map { Int($0.rawValue.hashValue) },
            family: self.family
        )
    }
}
