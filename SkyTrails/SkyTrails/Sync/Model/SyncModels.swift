import Foundation
import SwiftData

enum SyncStatus: String, Codable {
    case pendingOwner    // Guest-created, waiting for login adoption
    case pendingCreate  // Created locally, needs to sync to server
    case pendingUpdate  // Modified locally, needs to sync to server
    case pendingDelete  // Deleted locally, needs to sync to server
    case synced         // Successfully synced with server
    case failed         // Sync failed, needs retry
}

struct UserRow: Codable {
    let id: UUID
    let name: String
    let gender: String
    let email: String
    let profilePhoto: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case gender
        case email
        case profilePhoto = "profile_photo"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from user: User) {
        self.id = user.id
        self.name = user.name
        self.gender = user.gender
        self.email = user.email
        self.profilePhoto = user.profilePhoto
        self.createdAt = Date()
        self.updatedAt = nil
    }

    init(id: UUID, name: String, gender: String, email: String, profilePhoto: String?, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.name = name
        self.gender = gender
        self.email = email
        self.profilePhoto = profilePhoto
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toUser() -> User {
        User(
            id: id,
            name: name,
            gender: gender,
            email: email,
            profilePhoto: profilePhoto ?? "defaultProfile"
        )
    }
}

struct WatchlistRow: Codable {
    let id: UUID
    let ownerId: UUID?
    let type: String
    let title: String?
    let location: String?
    let locationDisplayName: String?
    let startDate: Date?
    let endDate: Date?
    let observedCount: Int
    let speciesCount: Int
    let coverImagePath: String?
    let speciesRuleEnabled: Bool
    let speciesRuleShapeId: String?
    let locationRuleEnabled: Bool
    let locationRuleLat: Double?
    let locationRuleLon: Double?
    let locationRuleRadiusKm: Double?
    let locationRuleDisplayName: String?
    let dateRuleEnabled: Bool
    let dateRuleStartDate: Date?
    let dateRuleEndDate: Date?
    let syncStatus: String
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case type
        case title
        case location
        case locationDisplayName = "location_display_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case observedCount = "observed_count"
        case speciesCount = "species_count"
        case coverImagePath = "cover_image_path"
        case speciesRuleEnabled = "species_rule_enabled"
        case speciesRuleShapeId = "species_rule_shape_id"
        case locationRuleEnabled = "location_rule_enabled"
        case locationRuleLat = "location_rule_lat"
        case locationRuleLon = "location_rule_lon"
        case locationRuleRadiusKm = "location_rule_radius_km"
        case locationRuleDisplayName = "location_rule_display_name"
        case dateRuleEnabled = "date_rule_enabled"
        case dateRuleStartDate = "date_rule_start_date"
        case dateRuleEndDate = "date_rule_end_date"
        case syncStatus = "sync_status"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WatchlistEntryRow: Codable {
    let id: UUID
    let watchlistId: UUID
    let birdId: UUID
    let nickname: String?
    let status: String
    let notes: String?
    let addedDate: Date
    let observationDate: Date?
    let toObserveStartDate: Date?
    let toObserveEndDate: Date?
    let observedBy: String?
    let lat: Double?
    let lon: Double?
    let locationDisplayName: String?
    let priority: Int
    let notifyUpcoming: Bool
    let targetDateRange: String?
    let syncStatus: String
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case watchlistId = "watchlist_id"
        case birdId = "bird_id"
        case nickname
        case status
        case notes
        case addedDate = "added_date"
        case observationDate = "observation_date"
        case toObserveStartDate = "to_observe_start_date"
        case toObserveEndDate = "to_observe_end_date"
        case observedBy = "observed_by"
        case lat
        case lon
        case locationDisplayName = "location_display_name"
        case priority
        case notifyUpcoming = "notify_upcoming"
        case targetDateRange = "target_date_range"
        case syncStatus = "sync_status"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WatchlistRuleRow: Codable {
    let id: UUID
    let watchlistId: UUID
    let ruleType: String
    let parametersJson: String
    let isActive: Bool
    let priority: Int
    let syncStatus: String
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case watchlistId = "watchlist_id"
        case ruleType = "rule_type"
        case parametersJson = "parameters_json"
        case isActive = "is_active"
        case priority
        case syncStatus = "sync_status"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WatchlistShareRow: Codable {
    let id: UUID
    let watchlistId: UUID
    let userId: UUID
    let permission: String
    let sharedAt: Date
    let sharedByUserId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case watchlistId = "watchlist_id"
        case userId = "user_id"
        case permission
        case sharedAt = "shared_at"
        case sharedByUserId = "shared_by_user_id"
    }
}

struct ObservedBirdPhotoRow: Codable {
    let id: UUID
    let watchlistEntryId: UUID
    let imagePath: String
    let storageUrl: String?
    let isUploaded: Bool
    let syncStatus: String
    let rowVersion: Int
    let lastSyncedAt: Date?
    let capturedAt: Date?
    let uploadedAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case watchlistEntryId = "watchlist_entry_id"
        case imagePath = "image_path"
        case storageUrl = "storage_url"
        case isUploaded = "is_uploaded"
        case syncStatus = "sync_status"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case capturedAt = "captured_at"
        case uploadedAt = "uploaded_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
