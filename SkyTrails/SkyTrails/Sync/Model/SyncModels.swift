import Foundation
import SwiftData

private enum MetadataScalarValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    nonisolated var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return String(value)
        case .null:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .null
        }
    }
}

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
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? WatchlistType.custom.rawValue
        title = try container.decodeIfPresent(String.self, forKey: .title)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        locationDisplayName = try container.decodeIfPresent(String.self, forKey: .locationDisplayName)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        observedCount = try container.decodeIfPresent(Int.self, forKey: .observedCount) ?? 0
        speciesCount = try container.decodeIfPresent(Int.self, forKey: .speciesCount) ?? 0
        coverImagePath = try container.decodeIfPresent(String.self, forKey: .coverImagePath)
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
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
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? WatchlistEntryStatus.to_observe.rawValue
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let decodedAddedDate = try container.decodeIfPresent(Date.self, forKey: .addedDate)
        let decodedCreatedDate = try container.decodeIfPresent(Date.self, forKey: .created_at)
        addedDate = decodedAddedDate ?? decodedCreatedDate ?? Date()
        observationDate = try container.decodeIfPresent(Date.self, forKey: .observationDate)
        toObserveStartDate = try container.decodeIfPresent(Date.self, forKey: .toObserveStartDate)
        toObserveEndDate = try container.decodeIfPresent(Date.self, forKey: .toObserveEndDate)
        observedBy = try container.decodeIfPresent(String.self, forKey: .observedBy)
        observedByUserId = try container.decodeIfPresent(UUID.self, forKey: .observedByUserId)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        locationDisplayName = try container.decodeIfPresent(String.self, forKey: .locationDisplayName)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        notifyUpcoming = try container.decodeIfPresent(Bool.self, forKey: .notifyUpcoming) ?? false
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? addedDate
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
        ruleType = try container.decodeIfPresent(String.self, forKey: .ruleType) ?? WatchlistRuleType.location.rawValue
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        radiusKm = try container.decodeIfPresent(Double.self, forKey: .radiusKm)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        shapeId = try container.decodeIfPresent(String.self, forKey: .shapeId)
        patternKey = try container.decodeIfPresent(String.self, forKey: .patternKey)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
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
        permission = try container.decodeIfPresent(String.self, forKey: .permission) ?? WatchlistSharePermission.view.rawValue
        sharedAt = try container.decodeIfPresent(Date.self, forKey: .sharedAt) ?? Date()
        sharedByUserId = try container.decodeIfPresent(UUID.self, forKey: .sharedByUserId)
        syncStatus = try container.decodeIfPresent(String.self, forKey: .syncStatus) ?? SyncStatus.synced.rawValue
        serverRowVersion = try container.decodeIfPresent(Int.self, forKey: .serverRowVersion) ?? 0
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
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        capturedAt = try container.decodeIfPresent(Date.self, forKey: .capturedAt)
        uploadedAt = try container.decodeIfPresent(Date.self, forKey: .uploadedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct BirdShapeRow: Decodable, Sendable {
    let serverId: UUID?
    let birdShapeId: String
    let name: String
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case birdShapeId = "bird_shape_id"
        case id
        case name
        case icon
        case iconURL = "icon_url"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverId = try container.decodeIfPresent(UUID.self, forKey: .id)
        if let explicitId = try container.decodeIfPresent(String.self, forKey: .birdShapeId) {
            birdShapeId = explicitId
        } else if let legacyUUID = try container.decodeIfPresent(UUID.self, forKey: .id) {
            birdShapeId = legacyUUID.uuidString
        } else if let legacyString = try container.decodeIfPresent(String.self, forKey: .id) {
            birdShapeId = legacyString
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.birdShapeId,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing bird shape identifier")
            )
        }
        name = try container.decode(String.self, forKey: .name)
        icon = try (
            container.decodeIfPresent(String.self, forKey: .icon)
            ?? container.decodeIfPresent(String.self, forKey: .iconURL)
        )
    }
}

struct BirdRow: Decodable, Sendable {
    let id: UUID
    let commonName: String
    let scientificName: String
    let imageURL: String?
    let family: String?
    let orderName: String?
    let description: String?
    let conservationStatus: String?
    let migrationStrategy: String?
    let shapeServerId: UUID?
    let shapeCode: String?
    let sizeCategory: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case birdId = "bird_id"
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case imageURL = "image_url"
        case family
        case orderName = "order_name"
        case description
        case conservationStatus = "conservation_status"
        case migrationStrategy = "migration_strategy"
        case shapeId = "shape_id"
        case sizeCategory = "size_category"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .birdId)
            ?? container.decode(UUID.self, forKey: .id)
        commonName = try container.decode(String.self, forKey: .commonName)
        scientificName = try container.decode(String.self, forKey: .scientificName)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        family = try container.decodeIfPresent(String.self, forKey: .family)
        orderName = try container.decodeIfPresent(String.self, forKey: .orderName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        conservationStatus = try container.decodeIfPresent(String.self, forKey: .conservationStatus)
        migrationStrategy = try container.decodeIfPresent(String.self, forKey: .migrationStrategy)
        sizeCategory = try container.decodeIfPresent(Int.self, forKey: .sizeCategory)

        if let shapeUUID = try container.decodeIfPresent(UUID.self, forKey: .shapeId) {
            shapeServerId = shapeUUID
            shapeCode = nil
        } else {
            shapeServerId = nil
            shapeCode = try container.decodeIfPresent(String.self, forKey: .shapeId)
        }
    }
}

struct BirdFieldMarkRow: Decodable, Sendable {
    let id: UUID
    let shapeId: String
    let area: String

    enum CodingKeys: String, CodingKey {
        case id = "bird_field_mark_id"
        case shapeId = "shape_id"
        case area
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        shapeId = try container.decode(String.self, forKey: .shapeId)
        area = try container.decode(String.self, forKey: .area)
    }
}

struct FieldMarkVariantRow: Decodable, Sendable {
    let id: UUID
    let fieldMarkId: UUID?
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "field_mark_variant_id"
        case fieldMarkId = "field_mark_id"
        case name
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fieldMarkId = try container.decodeIfPresent(UUID.self, forKey: .fieldMarkId)
        name = try container.decode(String.self, forKey: .name)
    }
}

struct BirdFieldMarkVariantLinkRow: Decodable, Sendable {
    let id: UUID
    let birdId: UUID
    let fieldMarkId: UUID?
    let variantId: UUID?
    let area: String

    enum CodingKeys: String, CodingKey {
        case id = "bird_field_mark_variant_link_id"
        case birdId = "bird_id"
        case fieldMarkId = "field_mark_id"
        case variantId = "variant_id"
        case area
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        birdId = try container.decode(UUID.self, forKey: .birdId)
        fieldMarkId = try container.decodeIfPresent(UUID.self, forKey: .fieldMarkId)
        variantId = try container.decodeIfPresent(UUID.self, forKey: .variantId)
        area = try container.decode(String.self, forKey: .area)
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

    init(
        id: UUID,
        userId: UUID,
        status: String,
        locationLat: Double?,
        locationLong: Double?,
        deviceInfo: String?,
        notes: String?,
        isPublic: Bool?,
        weatherConditions: String?,
        metadata: [String: String]?,
        created_at: Date,
        updated_at: Date?
    ) {
        self.id = id
        self.userId = userId
        self.status = status
        self.locationLat = locationLat
        self.locationLong = locationLong
        self.deviceInfo = deviceInfo
        self.notes = notes
        self.isPublic = isPublic
        self.weatherConditions = weatherConditions
        self.metadata = metadata
        self.created_at = created_at
        self.updated_at = updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        status = try container.decode(String.self, forKey: .status)
        locationLat = try container.decodeIfPresent(Double.self, forKey: .locationLat)
        locationLong = try container.decodeIfPresent(Double.self, forKey: .locationLong)
        deviceInfo = try container.decodeIfPresent(String.self, forKey: .deviceInfo)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic)
        weatherConditions = try container.decodeIfPresent(String.self, forKey: .weatherConditions)
        if let rawMetadata = try container.decodeIfPresent([String: MetadataScalarValue].self, forKey: .metadata) {
            let normalizedMetadata = rawMetadata.reduce(into: [String: String]()) { result, item in
                if let value = item.value.stringValue {
                    result[item.key] = value
                }
            }
            metadata = normalizedMetadata.isEmpty ? nil : normalizedMetadata
        } else {
            metadata = nil
        }
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
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

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        let decodedOwnerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
        let legacyOwnerId = try fallbackContainer.decodeIfPresent(UUID.self, forKey: .userIdFallback)
        ownerId = decodedOwnerId ?? legacyOwnerId
        birdId = try container.decodeIfPresent(UUID.self, forKey: .birdId)
        syncStatus = try container.decodeIfPresent(String.self, forKey: .syncStatus) ?? SyncStatus.synced.rawValue
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case userIdFallback = "user_id"
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

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        resultId = try container.decode(UUID.self, forKey: .resultId)
        birdId = try container.decode(UUID.self, forKey: .birdId)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        rank = try container.decodeIfPresent(Int.self, forKey: .rank)
        matchedFeatures = try container.decodeIfPresent([String].self, forKey: .matchedFeatures) ?? []
        mismatchedFeatures = try container.decodeIfPresent([String].self, forKey: .mismatchedFeatures) ?? []
        syncStatus = try container.decodeIfPresent(String.self, forKey: .syncStatus) ?? SyncStatus.synced.rawValue
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
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

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        fieldMarkId = try container.decode(UUID.self, forKey: .fieldMarkId)
        variantId = try container.decode(UUID.self, forKey: .variantId)
        area = try container.decodeIfPresent(String.self, forKey: .area) ?? ""
        syncStatus = try container.decodeIfPresent(String.self, forKey: .syncStatus) ?? SyncStatus.synced.rawValue
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}
