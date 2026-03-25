
import Foundation
import SwiftData
import CoreLocation

enum WatchlistType: String, Codable {
    case custom
    case shared
    case my_watchlist
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
    case migration_pattern
}

enum WatchlistMode {
    case observed
    case unobserved
}

@Model
final class Watchlist {
    @Attribute(.unique) var watchlist_id: UUID
    var user_id: UUID?
    var type: WatchlistType?
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var lastSyncedAt: Date?
    var serverRowVersion: Int = 0
    var deleted_at: Date?
    var title: String?
    
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    var location: String?
    var startDate: Date?
    var endDate: Date?
    var observedCount: Int = 0
    var speciesCount: Int = 0
    var created_at: Date = Date()
    var updated_at: Date?
    var locationDisplayName: String?
    var coverImagePath: String?
    @Relationship(deleteRule: .cascade, inverse: \WatchlistEntry.watchlist) var entries: [WatchlistEntry]?
    @Relationship(deleteRule: .cascade, inverse: \WatchlistRule.watchlist) var rules: [WatchlistRule]?
    @Relationship(deleteRule: .cascade, inverse: \WatchlistShare.watchlist) var shares: [WatchlistShare]?
    
    init(
        watchlist_id: UUID = UUID(),
        user_id: UUID? = nil,
        type: WatchlistType = .custom,
        title: String? = nil,
        location: String? = nil,
        locationDisplayName: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.watchlist_id = watchlist_id
        self.user_id = user_id
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
    var bird: Bird?
    
    var nickname: String?
    var status: WatchlistEntryStatus
    var notes: String?
    var addedDate: Date = Date()
    var observationDate: Date?
    var toObserveStartDate: Date?
    var toObserveEndDate: Date?
    var observedBy: String?
    var observedByUserId: UUID?
    var lat: Double?
    var lon: Double?
    var locationDisplayName: String?
    
    var priority: Int = 0
    var notify_upcoming: Bool = false
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var lastSyncedAt: Date?
    var serverRowVersion: Int = 0
    
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \ObservedBirdPhoto.watchlistEntry) var photos: [ObservedBirdPhoto]?
    
    init(
        id: UUID = UUID(),
        watchlist: Watchlist? = nil,
        bird: Bird? = nil,
        status: WatchlistEntryStatus = .to_observe,
        notes: String? = nil,
        observationDate: Date? = nil,
        observedBy: String? = nil,
        observedByUserId: UUID? = nil
    ) {
        self.id = id
        self.watchlist = watchlist
        self.bird = bird
        self.status = status
        self.notes = notes
        self.observationDate = observationDate
        self.observedBy = observedBy
        self.observedByUserId = observedByUserId
        self.addedDate = Date()
    }
}

@Model
final class WatchlistRule {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var rule_type: WatchlistRuleType
    var lat: Double?
    var lon: Double?
    var radius_km: Double?
    var start_date: Date?
    var end_date: Date?
    var shape_id: String?
    var pattern_key: String?
    var is_active: Bool = true
    var priority: Int = 0
    var created_at: Date = Date()
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var lastSyncedAt: Date?
    var serverRowVersion: Int = 0
    var deleted_at: Date?
    
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        watchlist: Watchlist? = nil,
        rule_type: WatchlistRuleType,
        lat: Double? = nil,
        lon: Double? = nil,
        radius_km: Double? = nil,
        start_date: Date? = nil,
        end_date: Date? = nil,
        shape_id: String? = nil,
        pattern_key: String? = nil
    ) {
        self.id = id
        self.watchlist = watchlist
        self.rule_type = rule_type
        self.lat = lat
        self.lon = lon
        self.radius_km = radius_km
        self.start_date = start_date
        self.end_date = end_date
        self.shape_id = shape_id
        self.pattern_key = pattern_key
    }
}

@Model
final class WatchlistShare {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var user_id: UUID
    var permission: WatchlistSharePermission
    var shared_at: Date = Date()
    var shared_by_user_id: UUID?
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var serverRowVersion: Int = 0
    var lastSyncedAt: Date?
    var deleted_at: Date?
    
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), watchlist: Watchlist? = nil, user_id: UUID, permission: WatchlistSharePermission = .view) {
        self.id = id
        self.watchlist = watchlist
        self.user_id = user_id
        self.permission = permission
    }
}

@Model
final class ObservedBirdPhoto {
    @Attribute(.unique) var id: UUID
    var watchlistEntry: WatchlistEntry?
    var imagePath: String
    var storageUrl: String?
    var syncStatusRaw: String = SyncStatus.pendingCreate.rawValue
    var lastSyncedAt: Date?
    var serverRowVersion: Int = 0
    var captured_at: Date?
    var uploaded_at: Date = Date()
    var created_at: Date = Date()
    
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), watchlistEntry: WatchlistEntry? = nil, imagePath: String) {
        self.id = id
        self.watchlistEntry = watchlistEntry
        self.imagePath = imagePath
        self.created_at = Date()
    }
}

extension Watchlist {
    func toDomain() -> WatchlistDetailDTO {
        let identifier = WatchlistIdentifier.from(uuid: self.watchlist_id, type: self.type)
        
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
            unobservedCount: max(self.speciesCount - self.observedCount, 0),
            totalCount: self.speciesCount
        )
        
        return WatchlistDetailDTO(
            id: identifier,
            title: self.title ?? "Unnamed Watchlist",
            location: self.location,
            locationDisplayName: self.locationDisplayName,
            dateRange: dateRange,
            stats: stats,
            type: self.type ?? .custom,
            images: [self.coverImagePath].compactMap { $0 },
            rules: self.rules?.map { $0.toDomain() } ?? [],
            isVirtual: identifier.isVirtual
        )
    }
    func toSummary(previewImages: [String] = []) -> WatchlistSummaryDTO {
        let identifier = WatchlistIdentifier.from(uuid: self.watchlist_id, type: self.type)
        
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
            unobservedCount: max(self.speciesCount - self.observedCount, 0),
            totalCount: self.speciesCount
        )
        
        return WatchlistSummaryDTO(
            id: identifier,
            title: self.title ?? "Unnamed Watchlist",
            subtitle: subtitle,
            dateText: dateText,
            image: self.coverImagePath,
            previewImages: previewImages,
            unobservedPreviewImages: [],
            observedPreviewImages: [],
            stats: stats,
            type: self.type ?? .custom
        )
    }
    func updateCoverImage() {
        guard let entries = self.entries, !entries.isEmpty else {
            self.coverImagePath = nil
            return
        }
        let observedEntries = entries.filter { $0.status == .observed && $0.observationDate != nil }
        let mostRecentObserved = observedEntries.max(by: { 
            ($0.observationDate ?? Date.distantPast) < ($1.observationDate ?? Date.distantPast) 
        })
        let toObserveEntries = entries.filter { $0.status == .to_observe }
        let mostRecentToObserve = toObserveEntries.max(by: { $0.addedDate < $1.addedDate })
        let observedDate = mostRecentObserved?.observationDate ?? Date.distantPast
        let toObserveDate = mostRecentToObserve?.addedDate ?? Date.distantPast
        
        let mostRecentEntry = observedDate > toObserveDate ? mostRecentObserved : mostRecentToObserve
        if let entry = mostRecentEntry {
            if let photoPath = entry.photos?.first?.imagePath {
                self.coverImagePath = photoPath
            } else if let staticImage = entry.bird?.staticImageName {
                self.coverImagePath = staticImage
            } else {
                self.coverImagePath = nil
            }
        } else {
            self.coverImagePath = nil
        }
    }
}

extension WatchlistEntry {
    func toDomain() -> WatchlistEntryDTO? {
        guard let bird = self.bird else { return nil }
        guard let watchlist = self.watchlist else { return nil }
        
        let watchlistID = WatchlistIdentifier.from(uuid: watchlist.watchlist_id, type: watchlist.type)
        
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
            observedByUserId: self.observedByUserId,
            location: location,
            photos: self.photos?.compactMap { $0.imagePath } ?? [],
            priority: self.priority,
            notifyUpcoming: self.notify_upcoming
        )
    }
}

extension WatchlistRule {
    func toDomain() -> WatchlistRuleDTO {
        let params = RuleParameters.from(rule: self)
            ?? .location(LocationRuleParams(lat: 0, lon: 0, radiusKm: 0))
        
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
    func toReference() -> BirdReferenceDTO {
        BirdReferenceDTO(
            id: self.bird_id,
            commonName: self.commonName,
            scientificName: self.scientificName,
            staticImageName: self.staticImageName,
            family: self.family
        )
    }
}
