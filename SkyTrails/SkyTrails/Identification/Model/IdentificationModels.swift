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
    var id: String  
    var name: String
    var icon: String

    @Relationship(deleteRule: .cascade, inverse: \BirdFieldMark.shape)
    var fieldMarks: [BirdFieldMark]?

    init(id: String, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

@Model
final class BirdFieldMark {
    @Attribute(.unique)
    var id: UUID
    
    var shape: BirdShape?
    var area: String
    @Relationship(deleteRule: .cascade, inverse: \FieldMarkVariant.fieldMark)
    var variants: [FieldMarkVariant]?

    var iconName: String {
        guard shape != nil else { return "" }
        return "id_bird_\(area.lowercased())"
    }

    init(area: String) {
        self.id = UUID()
        self.area = area
    }
}

@Model
final class FieldMarkVariant {
    @Attribute(.unique)
    var id: UUID
    
    var fieldMark: BirdFieldMark?
    var name: String


    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}



@Model
final class IdentificationSession {
    @Attribute(.unique)
    var id: UUID
    
    var ownerId: UUID?
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    var shape: BirdShape?
    
    var locationId: UUID?
    var locationDisplayName: String?
    var observationDate: Date
    var createdAt: Date
    
    var status: SessionStatus
    var sizeCategory: Int?
    var selectedFilterCategories: [String]?
    
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
        id: UUID = UUID(),
        ownerId: UUID? = nil,
        shape: BirdShape?,
        locationId: UUID? = nil,
        locationDisplayName: String? = nil,
        observationDate: Date,
        createdAt: Date = Date(),
        status: SessionStatus = .inProgress,
        sizeCategory: Int? = nil,
        selectedFilterCategories: [String]? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.syncStatusRaw = ownerId == nil ? SyncStatus.pendingOwner.rawValue : SyncStatus.pendingCreate.rawValue
        self.shape = shape
        self.locationId = locationId
        self.locationDisplayName = locationDisplayName
        self.observationDate = observationDate
        self.createdAt = createdAt
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
    var id: UUID
    
    var session: IdentificationSession?
    var fieldMark: BirdFieldMark?
    var variant: FieldMarkVariant?
    
    var area: String

    init(
        id: UUID = UUID(),
        session: IdentificationSession? = nil,
        fieldMark: BirdFieldMark?,
        variant: FieldMarkVariant? = nil,
        area: String
    ) {
        self.id = id
        self.session = session
        self.fieldMark = fieldMark
        self.variant = variant
        self.area = area
    }
}


@Model
final class IdentificationResult {
    @Attribute(.unique)
    var id: UUID
    
    var session: IdentificationSession?
    var ownerId: UUID?
    var syncStatus: SyncStatus?
    
    var bird: Bird?
    
    var createdAt: Date
    
    var serverRowVersion: Int64?
    var lastSyncedAt: Date?
    var deletedAt: Date?
    var created_at: Date
    var updated_at: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \IdentificationCandidate.result)
    var candidates: [IdentificationCandidate]?

    init(
        id: UUID = UUID(),
        session: IdentificationSession? = nil,
        ownerId: UUID? = nil,
        bird: Bird? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.session = session
        self.ownerId = ownerId
        self.syncStatus = ownerId == nil ? .pendingOwner : .pendingCreate
        self.bird = bird
        self.createdAt = createdAt
        self.created_at = createdAt
        self.updated_at = Date()
    }
}

@Model
final class IdentificationCandidate {
    @Attribute(.unique)
    var id: UUID
    
    var result: IdentificationResult?
    var bird: Bird?
    
    var confidence: Double
    var rank: Int?
    
    var syncStatus: SyncStatus?
    var serverRowVersion: Int64?
    var lastSyncedAt: Date?
    var deletedAt: Date?
    var created_at: Date
    var updated_at: Date?
    
    // Updated to use the struct instead of String
    var matchScore: MatchScore?

    init(
        id: UUID = UUID(),
        result: IdentificationResult? = nil,
        bird: Bird?,
        confidence: Double,
        rank: Int? = nil,
        matchScore: MatchScore? = nil
    ) {
        self.id = id
        self.result = result
        self.bird = bird
        self.confidence = confidence
        self.rank = rank
        self.matchScore = matchScore
        self.syncStatus = .pendingCreate
        self.created_at = Date()
        self.updated_at = Date()
    }
}
