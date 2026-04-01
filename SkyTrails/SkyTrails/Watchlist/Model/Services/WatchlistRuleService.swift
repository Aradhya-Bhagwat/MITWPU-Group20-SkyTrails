
import Foundation
import SwiftData
import CoreLocation

@MainActor
final class WatchlistRuleService {
    
    private let context: ModelContext
    private let persistence: WatchlistPersistenceService
    private let matcher = RuleMatchingService()
    
    init(context: ModelContext, persistence: WatchlistPersistenceService) {
        self.context = context
        self.persistence = persistence
    }
    func applyRules(to watchlistID: UUID) async throws {
        guard let watchlist = try persistence.fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let rules = try persistence.fetchRules(watchlistID: watchlistID, activeOnly: true)
        
        guard !rules.isEmpty else {
            return
        }
        var candidateBirds: Set<Bird> = []
        
        for rule in rules {
            let birds = try await applyRule(rule)
            candidateBirds.formUnion(birds)
        }
        if !candidateBirds.isEmpty {
            let _ = try persistence.addBirdsToWatchlist(
                watchlistID: watchlistID,
                birds: Array(candidateBirds),
                status: .to_observe
            )
            watchlist.updateCoverImage()
            do {
                try context.save()
            } catch {
                WatchlistLog.error("Failed to save after applying rules", error: error)
            }
        }
    }
    
    private func applyRule(_ rule: WatchlistRule) async throws -> Set<Bird> {
        guard let params = RuleParameters.from(rule: rule) else {
            throw WatchlistError.ruleValidationFailed("Failed to parse rule parameters")
        }
        
        switch params {
        case .location(let locationParams):
            return await applyLocationRule(locationParams)
        case .dateRange(let dateParams):
            return try applyDateRangeRule(dateParams)
        case .speciesFamily(let familyParams):
            return try applySpeciesFamilyRule(familyParams)
        case .migration(let migrationParams):
            return try applyMigrationRule(migrationParams)
        }
    }
    
    private func applyLocationRule(_ params: LocationRuleParams) async -> Set<Bird> {
        let location = CLLocationCoordinate2D(latitude: params.lat, longitude: params.lon)
        let hotspotManager = HotspotManager(modelContext: context)
        
        var allBirds = Set<Bird>()
        for week in 1...52 {
            let birds = await hotspotManager.getBirdsPresent(
                at: location,
                duringWeek: week,
                radiusInKm: params.radiusKm
            )
            allBirds.formUnion(birds)
        }
        return allBirds
    }
    
    private func applyDateRangeRule(_ params: DateRangeRuleParams) throws -> Set<Bird> {
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: params.startDate)
        let endMonth = calendar.component(.month, from: params.endDate)
        let allBirds = try persistence.fetchAllBirds()
        let validBirds = allBirds.filter { bird in
            guard let validMonths = bird.validMonths else { return false }
            if startMonth <= endMonth {
                return validMonths.contains(where: { $0 >= startMonth && $0 <= endMonth })
            } else {
                return validMonths.contains(where: { $0 >= startMonth || $0 <= endMonth })
            }
        }
        return Set(validBirds)
    }
    
    private func applySpeciesFamilyRule(_ params: SpeciesFamilyRuleParams) throws -> Set<Bird> {
        let allBirds = try persistence.fetchAllBirds()
        
        let matchingBirds = allBirds.filter { bird in
            matcher.matches(bird: bird, ruleParams: .speciesFamily(params), location: nil, observationDate: nil)
        }
        return Set(matchingBirds)
    }
    
    private func applyMigrationRule(_ params: MigrationPatternRuleParams) throws -> Set<Bird> {
        let allBirds = try persistence.fetchAllBirds()
        
        let matchingBirds = allBirds.filter { bird in
            matcher.matches(bird: bird, ruleParams: .migration(params), location: nil, observationDate: nil)
        }
        return Set(matchingBirds)
    }
    
    func validateRule(type: WatchlistRuleType, parameters: RuleParameters) throws {
        switch (type, parameters) {
        case (.location, .location(let params)):
            guard params.radiusKm > 0 && params.radiusKm <= 500 else {
                throw WatchlistError.ruleValidationFailed("Radius must be between 0 and 500 km")
            }
            guard abs(params.lat) <= 90 && abs(params.lon) <= 180 else {
                throw WatchlistError.ruleValidationFailed("Invalid coordinates")
            }
            
        case (.date_range, .dateRange(let params)):
            guard params.endDate > params.startDate else {
                throw WatchlistError.invalidDateRange
            }
            
        case (.species_family, .speciesFamily(let params)):
            guard !params.shapeId.isEmpty else {
                throw WatchlistError.ruleValidationFailed("Must specify shape id")
            }
            
        case (.migration_pattern, .migration(let params)):
            guard !params.patternKey.isEmpty else {
                throw WatchlistError.ruleValidationFailed("Must specify migration pattern key")
            }
            
        default:
            throw WatchlistError.ruleValidationFailed("Rule type and parameters mismatch")
        }
    }
}
