import Foundation
import SwiftData

enum SyncStatus: String, Codable {
    case pendingOwner
    case pendingCreate
    case pendingUpdate
    case pendingDelete
    case synced
    case failed
}

struct UserRow: Codable {
    let user_id: UUID
    let name: String
    let gender: String
    let email: String
    let profilePhoto: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case user_id
        case name
        case gender
        case email
        case profilePhoto = "profile_photo"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from user: User) {
        self.user_id = user.user_id
        self.name = user.name
        self.gender = user.gender
        self.email = user.email
        // If it's the default string, set to nil so we don't overwrite server-side URLs
        self.profilePhoto = user.profilePhoto == "defaultProfile" ? nil : user.profilePhoto
        self.createdAt = Date()
        self.updatedAt = nil
    }

    init(user_id: UUID, name: String, gender: String, email: String, profilePhoto: String?, createdAt: Date?, updatedAt: Date?) {
        self.user_id = user_id
        self.name = name
        self.gender = gender
        self.email = email
        self.profilePhoto = profilePhoto
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toUser() -> User {
        User(
            user_id: user_id,
            name: name,
            gender: gender,
            email: email,
            profilePhoto: profilePhoto ?? "defaultProfile"
        )
    }
}

struct WatchlistRow: Codable, Sendable {
    let watchlist_id: UUID
    let user_id: UUID?
    let type: String
    let title: String?
    let location: String?
    let locationDisplayName: String?
    let startDate: Date?
    let endDate: Date?
    let observedCount: Int
    let speciesCount: Int
    let coverImagePath: String?
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case watchlist_id
        case user_id
        case type
        case title
        case location
        case locationDisplayName = "location_display_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case observedCount = "observed_count"
        case speciesCount = "species_count"
        case coverImagePath = "cover_image_path"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchlist_id = try container.decode(UUID.self, forKey: .watchlist_id)
        user_id = try container.decodeIfPresent(UUID.self, forKey: .user_id)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        locationDisplayName = try container.decodeIfPresent(String.self, forKey: .locationDisplayName)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        observedCount = try container.decode(Int.self, forKey: .observedCount)
        speciesCount = try container.decode(Int.self, forKey: .speciesCount)
        coverImagePath = try container.decodeIfPresent(String.self, forKey: .coverImagePath)
        rowVersion = try container.decode(Int.self, forKey: .rowVersion)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decode(Date.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}

struct WatchlistEntryRow: Codable, Sendable {
    let id: UUID
    let watchlistId: UUID
    let birdId: UUID?
    let nickname: String?
    let status: String
    let notes: String?
    let addedDate: Date
    let observationDate: Date?
    let toObserveStartDate: Date?
    let toObserveEndDate: Date?
    let observedBy: String?
    let observedByUserId: UUID?
    let lat: Double?
    let lon: Double?
    let locationDisplayName: String?
    let priority: Int
    let notifyUpcoming: Bool
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "watchlist_entry_id"
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
        case observedByUserId = "observed_by_user_id"
        case lat
        case lon
        case locationDisplayName = "location_display_name"
        case priority
        case notifyUpcoming = "notify_upcoming"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        watchlistId = try container.decode(UUID.self, forKey: .watchlistId)
        birdId = try container.decodeIfPresent(UUID.self, forKey: .birdId)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        status = try container.decode(String.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        addedDate = try container.decode(Date.self, forKey: .addedDate)
        observationDate = try container.decodeIfPresent(Date.self, forKey: .observationDate)
        toObserveStartDate = try container.decodeIfPresent(Date.self, forKey: .toObserveStartDate)
        toObserveEndDate = try container.decodeIfPresent(Date.self, forKey: .toObserveEndDate)
        observedBy = try container.decodeIfPresent(String.self, forKey: .observedBy)
        observedByUserId = try container.decodeIfPresent(UUID.self, forKey: .observedByUserId)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        locationDisplayName = try container.decodeIfPresent(String.self, forKey: .locationDisplayName)
        priority = try container.decode(Int.self, forKey: .priority)
        notifyUpcoming = try container.decode(Bool.self, forKey: .notifyUpcoming)
        rowVersion = try container.decode(Int.self, forKey: .rowVersion)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decode(Date.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}

struct WatchlistRuleRow: Codable, Sendable {
    let id: UUID
    let watchlistId: UUID
    let ruleType: String
    let lat: Double?
    let lon: Double?
    let radiusKm: Double?
    let startDate: Date?
    let endDate: Date?
    let shapeId: String?
    let patternKey: String?
    let isActive: Bool
    let priority: Int
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "watchlist_rule_id"
        case watchlistId = "watchlist_id"
        case ruleType = "rule_type"
        case lat
        case lon
        case radiusKm = "radius_km"
        case startDate = "start_date"
        case endDate = "end_date"
        case shapeId = "shape_id"
        case patternKey = "pattern_key"
        case isActive = "is_active"
        case priority
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        watchlistId = try container.decode(UUID.self, forKey: .watchlistId)
        ruleType = try container.decode(String.self, forKey: .ruleType)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        radiusKm = try container.decodeIfPresent(Double.self, forKey: .radiusKm)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        shapeId = try container.decodeIfPresent(String.self, forKey: .shapeId)
        patternKey = try container.decodeIfPresent(String.self, forKey: .patternKey)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        priority = try container.decode(Int.self, forKey: .priority)
        rowVersion = try container.decode(Int.self, forKey: .rowVersion)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decode(Date.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}

struct WatchlistShareRow: Codable, Sendable {
    let id: UUID
    let watchlistId: UUID
    let userId: UUID
    let permission: String
    let sharedAt: Date
    let sharedByUserId: UUID?
    let syncStatus: String
    let serverRowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "watchlist_share_id"
        case watchlistId = "watchlist_id"
        case userId = "user_id"
        case permission
        case sharedAt = "shared_at"
        case sharedByUserId = "shared_by_user_id"
        case syncStatus = "sync_status"
        case serverRowVersion = "server_row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        watchlistId = try container.decode(UUID.self, forKey: .watchlistId)
        userId = try container.decode(UUID.self, forKey: .userId)
        permission = try container.decode(String.self, forKey: .permission)
        sharedAt = try container.decode(Date.self, forKey: .sharedAt)
        sharedByUserId = try container.decodeIfPresent(UUID.self, forKey: .sharedByUserId)
        syncStatus = try container.decode(String.self, forKey: .syncStatus)
        serverRowVersion = try container.decode(Int.self, forKey: .serverRowVersion)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct ObservedBirdPhotoRow: Codable, Sendable {
    let id: UUID
    let watchlistEntryId: UUID
    let imagePath: String
    let storageUrl: String?
    let rowVersion: Int
    let lastSyncedAt: Date?
    let capturedAt: Date?
    let uploadedAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "observed_bird_photo_id"
        case watchlistEntryId = "watchlist_entry_id"
        case imagePath = "image_path"
        case storageUrl = "storage_url"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case capturedAt = "captured_at"
        case uploadedAt = "uploaded_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        watchlistEntryId = try container.decode(UUID.self, forKey: .watchlistEntryId)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        storageUrl = try container.decodeIfPresent(String.self, forKey: .storageUrl)
        rowVersion = try container.decode(Int.self, forKey: .rowVersion)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        capturedAt = try container.decodeIfPresent(Date.self, forKey: .capturedAt)
        uploadedAt = try container.decodeIfPresent(Date.self, forKey: .uploadedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct IdentificationSessionRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let status: String
    let locationLat: Double?
    let locationLong: Double?
    let deviceInfo: String?
    let notes: String?
    let isPublic: Bool?
    let weatherConditions: String?
    let metadata: [String: String]?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "identification_session_id"
        case userId = "user_id"
        case status
        case locationLat = "location_lat"
        case locationLong = "location_long"
        case deviceInfo = "device_info"
        case notes
        case isPublic = "is_public"
        case weatherConditions = "weather_conditions"
        case metadata
        case created_at = "created_at"
        case updated_at = "updated_at"
    }
}

struct IdentificationResultRow: Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    let ownerId: UUID?
    let birdId: UUID?
    let syncStatus: String
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "identification_result_id"
        case sessionId = "identification_session_id"
        case ownerId = "owner_id"
        case birdId = "bird_id"
        case syncStatus = "sync_status"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }
}

struct IdentificationCandidateRow: Codable, Sendable {
    let id: UUID
    let resultId: UUID
    let birdId: UUID
    let confidence: Double
    let rank: Int?
    let matchedFeatures: [String]
    let mismatchedFeatures: [String]
    let syncStatus: String
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "identification_candidate_id"
        case resultId = "identification_result_id"
        case birdId = "bird_id"
        case confidence
        case rank = "confidence_rank"
        case matchedFeatures = "matched_features"
        case mismatchedFeatures = "mismatched_features"
        case syncStatus = "sync_status"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }
}

struct IdentificationSessionFieldMarkRow: Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    let fieldMarkId: UUID
    let variantId: UUID
    let area: String
    let syncStatus: String
    let rowVersion: Int
    let lastSyncedAt: Date?
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "identification_session_mark_id"
        case sessionId = "identification_session_id"
        case fieldMarkId = "field_mark_id"
        case variantId = "variant_id"
        case area
        case syncStatus = "sync_status"
        case rowVersion = "row_version"
        case lastSyncedAt = "last_synced_at"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }
}
