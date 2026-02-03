//
//  Models.swift
//  SkyTrails
//
//

import Foundation
import SwiftData

// MARK: - Enums

enum WatchlistType: String, Codable {
    case custom         // User-created with automation rules
    case shared         // Shared among multiple users
    case my_watchlist   // Virtual/derived - aggregation (Logic handled in Manager)
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
    static let defaultOwnerId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    
    @Attribute(.unique) var id: UUID
    var owner_id: UUID = Watchlist.defaultOwnerId
    var type: WatchlistType
    var title: String?
    var location: String?
    var startDate: Date?
    var endDate: Date?
    var observedCount: Int = 0
    var speciesCount: Int = 0
    var created_at: Date = Date()
    var updated_at: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \WatchlistEntry.watchlist)
    var entries: [WatchlistEntry]?
    
    @Relationship(deleteRule: .cascade, inverse: \WatchlistRule.watchlist)
    var rules: [WatchlistRule]?
    
    @Relationship(deleteRule: .cascade, inverse: \WatchlistShare.watchlist)
    var shares: [WatchlistShare]?
    
    @Relationship(deleteRule: .cascade, inverse: \WatchlistImage.watchlist)
    var images: [WatchlistImage]?
    
    init(
        id: UUID = UUID(),
        owner_id: UUID = Watchlist.defaultOwnerId,
        type: WatchlistType = .custom,
        title: String? = nil,
        location: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.id = id
        self.owner_id = owner_id
        self.type = type
        self.title = title
        self.location = location
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
    
    var priority: Int = 0
    var notify_upcoming: Bool = false
    var target_date_range: String? // Text description like "Oct - Nov"
    
    @Relationship(deleteRule: .cascade, inverse: \ObservedBirdPhoto.watchlistEntry)
    var photos: [ObservedBirdPhoto]?
    
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

// MARK: - Rule & Logic Models

@Model
final class WatchlistRule {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var rule_type: WatchlistRuleType
    var parameters_json: String
    var is_active: Bool = true
    var priority: Int = 0
    var created_at: Date = Date()
    
    init(
        id: UUID = UUID(),
        watchlist: Watchlist? = nil,
        rule_type: WatchlistRuleType,
        parameters: String
    ) {
        self.id = id
        self.watchlist = watchlist
        self.rule_type = rule_type
        self.parameters_json = parameters
    }
}

// MARK: - Metadata Models

@Model
final class WatchlistShare {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var user_id: UUID // The user it is shared WITH
    var permission: WatchlistSharePermission
    var shared_at: Date = Date()
    var shared_by_user_id: UUID?
    
    init(
        id: UUID = UUID(),
        watchlist: Watchlist? = nil,
        user_id: UUID,
        permission: WatchlistSharePermission = .view
    ) {
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
