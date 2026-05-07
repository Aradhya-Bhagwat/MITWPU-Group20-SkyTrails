import Foundation
import SwiftData

enum FilterCategory: String, CaseIterable, Identifiable {
    case locationDate = "Location & Date"
    case size = "Size"
    case shape = "Shape"
    case fieldMarks = "Field Marks"
    
    var id: Self { self }
    var icon: String {
        switch self {
        case .locationDate: return "home_icn_location_date_pin"
        case .size: return "id_icn_size"
        case .shape: return "id_icn_shape_bird_question"
        case .fieldMarks: return "id_icn_field_marks"
        }
    }
}
enum SessionStatus: String, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case abandoned = "abandoned"
}

struct MatchScore: Codable {
    var matchedFeatures: [String]
    var mismatchedFeatures: [String]
    var score: Double
}

@Model
final class BirdShape {
    @Attribute(.unique)
    var bird_shape_id: String
    var name: String
    var icon: String

    @Relationship(deleteRule: .cascade, inverse: \BirdFieldMark.shape)
    var fieldMarks: [BirdFieldMark]?

    @Relationship(deleteRule: .nullify, inverse: \Bird.shape)
    var birds: [Bird]?

    init(bird_shape_id: String, name: String, icon: String) {
        self.bird_shape_id = bird_shape_id
        self.name = name
        self.icon = icon
    }
}

@Model
final class BirdFieldMark {
    @Attribute(.unique)
    var bird_field_mark_id: UUID
    
    var shape: BirdShape?
    var area: String
    @Relationship(deleteRule: .cascade, inverse: \FieldMarkVariant.fieldMark)
    var variants: [FieldMarkVariant]?

    var iconName: String {
        guard shape != nil else { return "" }
        return "id_bird_\(area.lowercased())"
    }

    init(area: String) {
        self.bird_field_mark_id = UUID()
        self.area = area
    }
}

@Model
final class FieldMarkVariant {
    @Attribute(.unique)
    var field_mark_variant_id: UUID
    
    var fieldMark: BirdFieldMark?
    var name: String

    init(name: String) {
        self.field_mark_variant_id = UUID()
        self.name = name
    }
}

@Model
final class IdentificationSession {
    @Attribute(.unique)
    var identification_session_id: UUID
    
    var user_id: UUID?
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    var shape: BirdShape?
    
    var locationId: UUID?
    var locationDisplayName: String?
    var observationDate: Date
    
    var status: SessionStatus
    var sizeCategory: Int?
    var selectedFilterCategories: [String]?
    
    var locationLat: Double?
    var locationLong: Double?
    var deviceInfo: String?
    var notes: String?
    var isPublic: Bool = false
    var weatherConditions: String?
    var metadata: [String: String]?
    
    var serverRowVersion: Int64?
    var lastSyncedAt: Date?
    var deletedAt: Date?
    var created_at: Date
    var updated_at: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \IdentificationSessionFieldMark.session)
    var selectedMarks: [IdentificationSessionFieldMark]?
    
    @Relationship(deleteRule: .cascade, inverse: \IdentificationResult.session)
    var result: IdentificationResult?

    init(
        identification_session_id: UUID = UUID(),
        user_id: UUID? = nil,
        shape: BirdShape? = nil,
        locationId: UUID? = nil,
        locationDisplayName: String? = nil,
        observationDate: Date = Date(),
        createdAt: Date = Date(),
        status: SessionStatus = .inProgress,
        sizeCategory: Int? = nil,
        selectedFilterCategories: [String]? = nil
    ) {
        self.identification_session_id = identification_session_id
        self.user_id = user_id
        self.syncStatusRaw = user_id == nil ? SyncStatus.pendingOwner.rawValue : SyncStatus.pendingCreate.rawValue
        self.shape = shape
        self.locationId = locationId
        self.locationDisplayName = locationDisplayName
        self.observationDate = observationDate
        self.status = status
        self.sizeCategory = sizeCategory
        self.selectedFilterCategories = selectedFilterCategories
        self.created_at = createdAt
        self.updated_at = Date()
    }
}

@Model
final class IdentificationSessionFieldMark {
    @Attribute(.unique)
    var identification_session_mark_id: UUID
    
    var identification_session_id: UUID
    var session: IdentificationSession?
    var field_mark_id: UUID
    var fieldMark: BirdFieldMark?
    var variant_id: UUID
    var variant: FieldMarkVariant?
    var area: String
    var overlayColorHex: String?

    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    var serverRowVersion: Int64?
    var lastSyncedAt: Date?
    var deletedAt: Date?
    var created_at: Date
    var updated_at: Date?

    init(
        identification_session_mark_id: UUID = UUID(),
        identification_session_id: UUID? = nil,
        session: IdentificationSession? = nil,
        field_mark_id: UUID? = nil,
        fieldMark: BirdFieldMark? = nil,
        variant_id: UUID? = nil,
        variant: FieldMarkVariant? = nil,
        area: String
    ) {
        self.identification_session_mark_id = identification_session_mark_id
        
        self.identification_session_id = identification_session_id ?? session?.identification_session_id ?? UUID()
        self.session = session
        
        self.field_mark_id = field_mark_id ?? fieldMark?.bird_field_mark_id ?? UUID()
        self.fieldMark = fieldMark
        
        self.variant_id = variant_id ?? variant?.field_mark_variant_id ?? UUID()
        self.variant = variant
        
        self.area = area
        self.created_at = Date()
        self.updated_at = Date()
    }
}

@Model
final class IdentificationResult {
    @Attribute(.unique)
    var identification_result_id: UUID
    
    var session: IdentificationSession?
    var user_id: UUID?
    
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    var bird: Bird?
    
    var serverRowVersion: Int64?
    var lastSyncedAt: Date?
    var deletedAt: Date?
    var created_at: Date
    var updated_at: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \IdentificationCandidate.result)
    var candidates: [IdentificationCandidate]?

    init(
        identification_result_id: UUID = UUID(),
        session: IdentificationSession? = nil,
        user_id: UUID? = nil,
        bird: Bird? = nil,
        createdAt: Date = Date()
    ) {
        self.identification_result_id = identification_result_id
        self.session = session
        self.user_id = user_id
        self.syncStatusRaw = user_id == nil ? SyncStatus.pendingOwner.rawValue : SyncStatus.pendingCreate.rawValue
        self.bird = bird
        self.created_at = createdAt
        self.updated_at = Date()
    }
}

enum IdentificationRelationshipBinder {
    static func bind(_ result: IdentificationResult, to session: IdentificationSession?) {
        if let previousSession = result.session,
           previousSession !== session,
           previousSession.result === result {
            previousSession.result = nil
        }

        if let session,
           let existingResult = session.result,
           existingResult !== result {
            existingResult.session = nil
            session.result = nil
        }

        result.session = session

        if session?.result !== result {
            session?.result = result
        }
    }
}

@Model
final class IdentificationCandidate {
    @Attribute(.unique)
    var identification_candidate_id: UUID
    
    var result: IdentificationResult?
    var bird: Bird?
    
    var confidence: Double
    var rank: Int?
    
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    var serverRowVersion: Int64?
    var lastSyncedAt: Date?
    var deletedAt: Date?
    var created_at: Date
    var updated_at: Date?
    var matchScore: MatchScore?

    init(
        identification_candidate_id: UUID = UUID(),
        result: IdentificationResult? = nil,
        bird: Bird?,
        confidence: Double,
        rank: Int? = nil,
        matchScore: MatchScore? = nil
    ) {
        self.identification_candidate_id = identification_candidate_id
        self.result = result
        self.bird = bird
        self.confidence = confidence
        self.rank = rank
        self.matchScore = matchScore
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.created_at = Date()
        self.updated_at = Date()
    }
}
