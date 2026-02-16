//
//  WatchlistRuleService.swift
//  SkyTrails
//
//  Rule Engine & Automation Logic
//  Strict MVC Refactoring
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class WatchlistRuleService {
    
    private let context: ModelContext
    private let persistence: WatchlistPersistenceService
    
    init(context: ModelContext, persistence: WatchlistPersistenceService) {
        self.context = context
        self.persistence = persistence
    }
    
    // MARK: - Rule Engine
    
    /// Apply all active rules to a watchlist and auto-add matching birds
    func applyRules(to watchlistID: UUID) async throws {
        print("🤖 [RuleService] Applying rules to watchlist \(watchlistID)")
        
        guard let watchlist = try persistence.fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let rules = try persistence.fetchRules(watchlistID: watchlistID, activeOnly: true)
        
        guard !rules.isEmpty else {
            print("⚠️ [RuleService] No active rules found")
            return
        }
        
        print("🤖 [RuleService] Found \(rules.count) active rules")
        
        var candidateBirds: Set<Bird> = []
        
        for rule in rules {
            print("🔧 [RuleService] Processing rule: \(rule.rule_type.rawValue) (priority: \(rule.priority))")
            
            let birds = try await applyRule(rule)
            candidateBirds.formUnion(birds)
        }
        
        print("🤖 [RuleService] Total candidate birds: \(candidateBirds.count)")
        
        // Add birds to watchlist (avoiding duplicates)
        if !candidateBirds.isEmpty {
            let _ = try persistence.addBirdsToWatchlist(
                watchlistID: watchlistID,
                birds: Array(candidateBirds),
                status: .to_observe
            )
        }
    }
    
    // MARK: - Individual Rule Processors
    
    private func applyRule(_ rule: WatchlistRule) async throws -> Set<Bird> {
        guard let params = RuleParameters.from(type: rule.rule_type, json: rule.parameters_json) else {
            throw WatchlistError.ruleValidationFailed("Failed to parse rule parameters")
        }
        
        switch params {
        case .location(let locationParams):
            return await applyLocationRule(locationParams)
        case .dateRange(let dateParams):
            return try applyDateRangeRule(dateParams)
        case .speciesFamily(let familyParams):
            return try applySpeciesFamilyRule(familyParams)
        case .rarity(let rarityParams):
            return try applyRarityRule(rarityParams)
        case .migration(let migrationParams):
            return try applyMigrationRule(migrationParams)
        }
    }
    
    private func applyLocationRule(_ params: LocationRuleParams) async -> Set<Bird> {
        print("📍 [RuleService] Applying location rule")
        
        let location = CLLocationCoordinate2D(latitude: params.lat, longitude: params.lon)
        let hotspotManager = HotspotManager(modelContext: context)
        
        var allBirds = Set<Bird>()
        
        if let weeks = params.validWeeks {
            // Specific weeks
            for week in weeks {
                let birds = hotspotManager.getBirdsPresent(
                    at: location,
                    duringWeek: week,
                    radiusInKm: params.radiusKm
                )
                allBirds.formUnion(birds)
            }
        } else {
            // All weeks (1-52)
            for week in 1...52 {
                let birds = hotspotManager.getBirdsPresent(
                    at: location,
                    duringWeek: week,
                    radiusInKm: params.radiusKm
                )
                allBirds.formUnion(birds)
            }
        }
        
        print("📍 [RuleService] Location rule found \(allBirds.count) birds")
        return allBirds
    }
    
    private func applyDateRangeRule(_ params: DateRangeRuleParams) throws -> Set<Bird> {
        print("📅 [RuleService] Applying date range rule")
        
        // Get calendar months from date range
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: params.startDate)
        let endMonth = calendar.component(.month, from: params.endDate)
        
        // Fetch all birds
        let allBirds = try persistence.fetchAllBirds()
        
        // Filter birds that are valid during this date range
        let validBirds = allBirds.filter { bird in
            guard let validMonths = bird.validMonths else { return false }
            
            // Check if any valid month falls in the range
            if startMonth <= endMonth {
                return validMonths.contains(where: { $0 >= startMonth && $0 <= endMonth })
            } else {
                // Range crosses year boundary
                return validMonths.contains(where: { $0 >= startMonth || $0 <= endMonth })
            }
        }
        
        print("📅 [RuleService] Date range rule found \(validBirds.count) birds")
        return Set(validBirds)
    }
    
    private func applySpeciesFamilyRule(_ params: SpeciesFamilyRuleParams) throws -> Set<Bird> {
        print("🦆 [RuleService] Applying species family rule")
        
        let allBirds = try persistence.fetchAllBirds()
        
        let matchingBirds = allBirds.filter { bird in
            guard let family = bird.family else { return false }
            return params.families.contains(family)
        }
        
        print("🦆 [RuleService] Species family rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    private func applyRarityRule(_ params: RarityRuleParams) throws -> Set<Bird> {
        print("💎 [RuleService] Applying rarity rule")
        
        let allBirds = try persistence.fetchAllBirds()
        
        let matchingBirds = allBirds.filter { bird in
            guard let rarityLevel = bird.rarityLevel else { return false }
            
            // Map rarity level to int for comparison
            let rarityInt: Int
            switch rarityLevel {
            case .common: rarityInt = 1
            case .uncommon: rarityInt = 2
            case .rare: rarityInt = 3
            case .very_rare: rarityInt = 4
            case .extremely_rare: rarityInt = 5
            }
            
            return params.levels.contains(rarityInt)
        }
        
        print("💎 [RuleService] Rarity rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    private func applyMigrationRule(_ params: MigrationPatternRuleParams) throws -> Set<Bird> {
        print("🛫 [RuleService] Applying migration pattern rule")
        
        let allBirds = try persistence.fetchAllBirds()
        
        let matchingBirds = allBirds.filter { bird in
            guard let strategy = bird.migration_strategy else { return false }
            
            let strategyMatches = params.strategies.contains(strategy)
            
            if let hemisphere = params.hemisphere {
                return strategyMatches && bird.hemisphere == hemisphere
            }
            
            return strategyMatches
        }
        
        print("🛫 [RuleService] Migration pattern rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    // MARK: - Rule Validation
    
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
            guard !params.families.isEmpty else {
                throw WatchlistError.ruleValidationFailed("Must specify at least one family")
            }
            
        case (.rarity_level, .rarity(let params)):
            guard !params.levels.isEmpty else {
                throw WatchlistError.ruleValidationFailed("Must specify at least one rarity level")
            }
            guard params.levels.allSatisfy({ $0 >= 1 && $0 <= 5 }) else {
                throw WatchlistError.ruleValidationFailed("Rarity levels must be between 1 and 5")
            }
            
        case (.migration_pattern, .migration(let params)):
            guard !params.strategies.isEmpty else {
                throw WatchlistError.ruleValidationFailed("Must specify at least one migration strategy")
            }
            
        default:
            throw WatchlistError.ruleValidationFailed("Rule type and parameters mismatch")
        }
    }
}
