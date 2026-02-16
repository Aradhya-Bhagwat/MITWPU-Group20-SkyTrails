//
//  WatchlistPersistenceService.swift
//  SkyTrails
//
//  Pure CRUD operations on SwiftData - NO business logic
//  Strict MVC Refactoring
//

import Foundation
import SwiftData

// Type alias for compatibility
typealias RarityLevel = BirdRarityLevel

@MainActor
final class WatchlistPersistenceService {
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Watchlist CRUD
    
    func createWatchlist(
        title: String,
        location: String?,
        locationDisplayName: String?,
        startDate: Date?,
        endDate: Date?,
        type: WatchlistType = .custom
    ) throws -> Watchlist {
        let watchlist = Watchlist(
            title: title,
            location: location,
            locationDisplayName: locationDisplayName,
            startDate: startDate,
            endDate: endDate
        )
        watchlist.type = type
        
        context.insert(watchlist)
        try saveContext()
        return watchlist
    }
    
    func fetchWatchlist(id: UUID) throws -> Watchlist? {
        let descriptor = FetchDescriptor<Watchlist>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchWatchlists(type: WatchlistType? = nil) throws -> [Watchlist] {
        var descriptor = FetchDescriptor<Watchlist>(
            sortBy: [SortDescriptor(\.created_at, order: .reverse)]
        )
        
        // Note: SwiftData enum predicates are limited, filter post-fetch if type is specified
        let all = try context.fetch(descriptor)
        
        if let type = type {
            return all.filter { $0.type == type }
        }
        return all
    }
    
    func updateWatchlist(
        id: UUID,
        title: String?,
        location: String?,
        locationDisplayName: String?,
        startDate: Date?,
        endDate: Date?
    ) throws {
        guard let watchlist = try fetchWatchlist(id: id) else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        
        if let title = title { watchlist.title = title }
        if let location = location { watchlist.location = location }
        if let locationDisplayName = locationDisplayName { watchlist.locationDisplayName = locationDisplayName }
        if let startDate = startDate { watchlist.startDate = startDate }
        if let endDate = endDate { watchlist.endDate = endDate }
        
        watchlist.updated_at = Date()
        try saveContext()
    }
    
    func deleteWatchlist(id: UUID) throws {
        let descriptor = FetchDescriptor<Watchlist>(
            predicate: #Predicate { $0.id == id }
        )
        guard let watchlist = try context.fetch(descriptor).first else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        
        context.delete(watchlist)
        try saveContext()
    }
    
    func updateWatchlistStats(id: UUID, observedCount: Int, speciesCount: Int) throws {
        guard let watchlist = try fetchWatchlist(id: id) else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        
        watchlist.observedCount = observedCount
        watchlist.speciesCount = speciesCount
        watchlist.updated_at = Date()
        try saveContext()
    }
    
    // MARK: - Entry CRUD
    
    func createEntry(
        watchlistID: UUID,
        bird: Bird,
        status: WatchlistEntryStatus,
        notes: String? = nil,
        observationDate: Date? = nil,
        toObserveStartDate: Date? = nil,
        toObserveEndDate: Date? = nil
    ) throws -> WatchlistEntry {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let entry = WatchlistEntry(
            watchlist: watchlist,
            bird: bird,
            status: status,
            notes: notes,
            observationDate: observationDate
        )
        entry.toObserveStartDate = toObserveStartDate
        entry.toObserveEndDate = toObserveEndDate
        
        if status == .observed && observationDate == nil {
            entry.observationDate = Date()
        }
        
        context.insert(entry)
        try saveContext()
        
        // Update watchlist stats
        try recalculateWatchlistStats(watchlistID: watchlistID)
        
        return entry
    }
    
    func fetchEntry(id: UUID) throws -> WatchlistEntry? {
        let descriptor = FetchDescriptor<WatchlistEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchEntries(watchlistID: UUID, status: WatchlistEntryStatus? = nil) throws -> [WatchlistEntry] {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        var entries = watchlist.entries ?? []
        
        if let status = status {
            entries = entries.filter { $0.status == status }
        }
        
        return entries.sorted { $0.addedDate < $1.addedDate }
    }
    
    func fetchAllEntries() throws -> [WatchlistEntry] {
        let descriptor = FetchDescriptor<WatchlistEntry>(
            sortBy: [SortDescriptor(\.addedDate)]
        )
        return try context.fetch(descriptor)
    }
    
    func updateEntry(
        id: UUID,
        notes: String?,
        observationDate: Date?,
        lat: Double?,
        lon: Double?,
        locationDisplayName: String?,
        toObserveStartDate: Date?,
        toObserveEndDate: Date?
    ) throws {
        guard let entry = try fetchEntry(id: id) else {
            throw WatchlistError.entryNotFound(id)
        }
        
        entry.notes = notes
        entry.observationDate = observationDate
        entry.lat = lat
        entry.lon = lon
        entry.locationDisplayName = locationDisplayName
        entry.toObserveStartDate = toObserveStartDate
        entry.toObserveEndDate = toObserveEndDate
        
        try saveContext()
        
        // Update parent watchlist stats
        if let watchlistID = entry.watchlist?.id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
    }
    
    func deleteEntry(id: UUID) throws {
        let descriptor = FetchDescriptor<WatchlistEntry>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entry = try context.fetch(descriptor).first else {
            throw WatchlistError.entryNotFound(id)
        }
        
        let watchlistID = entry.watchlist?.id
        
        context.delete(entry)
        try saveContext()
        
        // Update parent watchlist stats
        if let watchlistID = watchlistID {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
    }
    
    func toggleEntryStatus(id: UUID) throws {
        guard let entry = try fetchEntry(id: id) else {
            throw WatchlistError.entryNotFound(id)
        }
        
        entry.status = (entry.status == .observed) ? .to_observe : .observed
        entry.observationDate = (entry.status == .observed) ? Date() : nil
        
        try saveContext()
        
        // Update parent watchlist stats
        if let watchlistID = entry.watchlist?.id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
    }
    
    func addBirdsToWatchlist(
        watchlistID: UUID,
        birds: [Bird],
        status: WatchlistEntryStatus
    ) throws -> [WatchlistEntry] {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let existingBirdIDs = Set((watchlist.entries ?? []).compactMap { $0.bird?.id })
        var createdEntries: [WatchlistEntry] = []
        
        for bird in birds {
            // Skip if already exists
            guard !existingBirdIDs.contains(bird.id) else {
                continue
            }
            
            let entry = WatchlistEntry(
                watchlist: watchlist,
                bird: bird,
                status: status
            )
            
            if status == .observed {
                entry.observationDate = Date()
            }
            
            context.insert(entry)
            createdEntries.append(entry)
        }
        
        if !createdEntries.isEmpty {
            try saveContext()
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
        
        return createdEntries
    }
    
    // MARK: - Rule CRUD
    
    func createRule(
        watchlistID: UUID,
        type: WatchlistRuleType,
        parameters: RuleParameters,
        priority: Int = 0,
        isActive: Bool = true
    ) throws -> WatchlistRule {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let rule = WatchlistRule(
            watchlist: watchlist,
            rule_type: type,
            parameters: parameters.jsonString
        )
        rule.priority = priority
        rule.is_active = isActive
        
        context.insert(rule)
        try saveContext()
        
        return rule
    }
    
    func fetchRules(watchlistID: UUID, activeOnly: Bool = false) throws -> [WatchlistRule] {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        var rules = watchlist.rules ?? []
        
        if activeOnly {
            rules = rules.filter { $0.is_active }
        }
        
        return rules.sorted { $0.priority > $1.priority }
    }
    
    func toggleRule(id: UUID) throws {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let rule = try context.fetch(descriptor).first else {
            throw WatchlistError.ruleValidationFailed("Rule not found")
        }
        
        rule.is_active = !rule.is_active
        try saveContext()
    }
    
    func deleteRule(id: UUID) throws {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let rule = try context.fetch(descriptor).first else {
            throw WatchlistError.ruleValidationFailed("Rule not found")
        }
        
        context.delete(rule)
        try saveContext()
    }
    
    // MARK: - Bird CRUD
    
    func fetchBird(id: UUID) throws -> Bird? {
        let descriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchBird(byCommonName name: String) throws -> Bird? {
        let descriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { $0.commonName == name }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchAllBirds() throws -> [Bird] {
        let descriptor = FetchDescriptor<Bird>(
            sortBy: [SortDescriptor(\.commonName)]
        )
        return try context.fetch(descriptor)
    }
    
    func createBird(
        commonName: String,
        scientificName: String = "Unknown",
        staticImageName: String = "photo",
        rarityLevel: RarityLevel = .common
    ) throws -> Bird {
        // Check for duplicate
        if let existing = try fetchBird(byCommonName: commonName) {
            throw WatchlistError.duplicateEntry(birdName: commonName)
        }
        
        let bird = Bird(
            id: UUID(),
            commonName: commonName,
            scientificName: scientificName,
            staticImageName: staticImageName,
            rarityLevel: rarityLevel,
            validLocations: []
        )
        
        context.insert(bird)
        try saveContext()
        
        return bird
    }
    
    // MARK: - Private Helpers
    
    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
    }
    
    private func recalculateWatchlistStats(watchlistID: UUID) throws {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else { return }
        
        let entries = watchlist.entries ?? []
        let observedCount = entries.filter { $0.status == .observed }.count
        let totalCount = entries.count
        
        watchlist.observedCount = observedCount
        watchlist.speciesCount = totalCount
        watchlist.updated_at = Date()
        
        try saveContext()
    }
}
