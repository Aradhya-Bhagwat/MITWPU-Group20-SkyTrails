//
//  LocationRuleParams.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/02/26.
//


//
//  WatchlistRuleEngine.swift
//  SkyTrails
//
//  Automated rule processing for watchlists
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Rule Parameter Models

struct LocationRuleParams: Codable {
    let latitude: Double
    let longitude: Double
    let radiusKm: Double
    let weeks: [Int]? // Optional: specific weeks, or nil for all weeks
}

struct DateRangeRuleParams: Codable {
    let startDate: Date
    let endDate: Date
}

struct SpeciesFamilyRuleParams: Codable {
    let families: [String] // e.g., ["Anatidae", "Laridae"]
}

struct RarityRuleParams: Codable {
    let levels: [String] // e.g., ["rare", "very_rare"]
}

struct MigrationPatternRuleParams: Codable {
    let strategies: [String] // e.g., ["long_distance", "altitudinal"]
    let hemisphere: String? // Optional: "northern" or "southern"
}

// MARK: - Rule Engine Extension

extension WatchlistManager {
    
    /// Apply all active rules to a watchlist and auto-add birds
    func applyRules(to watchlistId: UUID) async {
        print("🤖 [RuleEngine] Applying rules to watchlist \(watchlistId)")
        
        guard let watchlist = getWatchlist(by: watchlistId),
              let rules = watchlist.rules?.filter({ $0.is_active }) else {
            print("⚠️ [RuleEngine] No watchlist or no active rules")
            return
        }
        
        print("🤖 [RuleEngine] Found \(rules.count) active rules")
        
        var candidateBirds: Set<Bird> = []
        
        for rule in rules.sorted(by: { $0.priority > $1.priority }) {
            print("🔧 [RuleEngine] Processing rule: \(rule.rule_type.rawValue) (priority: \(rule.priority))")
            
            switch rule.rule_type {
            case .location:
                candidateBirds.formUnion(await applyLocationRule(rule))
            case .date_range:
                candidateBirds.formUnion(applyDateRangeRule(rule))
            case .species_family:
                candidateBirds.formUnion(applySpeciesFamilyRule(rule))
            case .rarity_level:
                candidateBirds.formUnion(applyRarityRule(rule))
            case .migration_pattern:
                candidateBirds.formUnion(applyMigrationRule(rule))
            }
        }
        
        print("🤖 [RuleEngine] Total candidate birds: \(candidateBirds.count)")
        
        // Add birds to watchlist (avoiding duplicates)
        if !candidateBirds.isEmpty {
            addBirds(Array(candidateBirds), to: watchlistId, asObserved: false)
        }
    }
    
    // MARK: - Individual Rule Processors
    
    private func applyLocationRule(_ rule: WatchlistRule) async -> Set<Bird> {
        print("📍 [RuleEngine] Applying location rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(LocationRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse location rule params")
            return []
        }
        
        let location = CLLocationCoordinate2D(latitude: params.latitude, longitude: params.longitude)
        let hotspotManager = HotspotManager(modelContext: context)
        
        var allBirds = Set<Bird>()
        
        if let weeks = params.weeks {
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
        
        print("📍 [RuleEngine] Location rule found \(allBirds.count) birds")
        return allBirds
    }
    
    private func applyDateRangeRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("📅 [RuleEngine] Applying date range rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(DateRangeRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse date range rule params")
            return []
        }
        
        // Get calendar months from date range
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: params.startDate)
        let endMonth = calendar.component(.month, from: params.endDate)
        
        // Fetch all birds
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
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
        
        print("📅 [RuleEngine] Date range rule found \(validBirds.count) birds")
        return Set(validBirds)
    }
    
    private func applySpeciesFamilyRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("🦆 [RuleEngine] Applying species family rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(SpeciesFamilyRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse species family rule params")
            return []
        }
        
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
        let matchingBirds = allBirds.filter { bird in
            guard let family = bird.family else { return false }
            return params.families.contains(family)
        }
        
        print("🦆 [RuleEngine] Species family rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    private func applyRarityRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("💎 [RuleEngine] Applying rarity rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(RarityRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse rarity rule params")
            return []
        }
        
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
        let matchingBirds = allBirds.filter { bird in
            guard let rarityLevel = bird.rarityLevel else { return false }
            return params.levels.contains(rarityLevel.rawValue)
        }
        
        print("💎 [RuleEngine] Rarity rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    private func applyMigrationRule(_ rule: WatchlistRule) -> Set<Bird> {
        print("🛫 [RuleEngine] Applying migration pattern rule")
        
        guard let jsonData = rule.parameters_json.data(using: .utf8),
              let params = try? JSONDecoder().decode(MigrationPatternRuleParams.self, from: jsonData) else {
            print("❌ [RuleEngine] Failed to parse migration pattern rule params")
            return []
        }
        
        let descriptor = FetchDescriptor<Bird>()
        guard let allBirds = try? context.fetch(descriptor) else { return [] }
        
        let matchingBirds = allBirds.filter { bird in
            guard let strategy = bird.migration_strategy else { return false }
            
            let strategyMatches = params.strategies.contains(strategy)
            
            if let hemisphere = params.hemisphere {
                return strategyMatches && bird.hemisphere == hemisphere
            }
            
            return strategyMatches
        }
        
        print("🛫 [RuleEngine] Migration pattern rule found \(matchingBirds.count) birds")
        return Set(matchingBirds)
    }
    
    // MARK: - Rule Management
    
    /// Add a rule to a watchlist
    func addRule(
        to watchlistId: UUID,
        type: WatchlistRuleType,
        parameters: Encodable,
        priority: Int = 0
    ) throws {
        guard let watchlist = getWatchlist(by: watchlistId) else {
            throw RepositoryError.watchlistNotFound(watchlistId)
        }
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(parameters)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "WatchlistManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode parameters"])
        }
        
        let rule = WatchlistRule(
            watchlist: watchlist,
            rule_type: type,
            parameters: jsonString
        )
        rule.priority = priority
        
        context.insert(rule)
        saveContext()
        
        print("✅ [RuleEngine] Added \(type.rawValue) rule to watchlist")
    }
    
    /// Toggle rule active status
    func toggleRule(ruleId: UUID) {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == ruleId }
        )
        
        if let rule = try? context.fetch(descriptor).first {
            rule.is_active = !rule.is_active
            saveContext()
            print("🔧 [RuleEngine] Toggled rule \(ruleId) to \(rule.is_active ? "active" : "inactive")")
        }
    }
    
    /// Delete a rule
    func deleteRule(ruleId: UUID) {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == ruleId }
        )
        
        if let rule = try? context.fetch(descriptor).first {
            context.delete(rule)
            saveContext()
            print("🗑️ [RuleEngine] Deleted rule \(ruleId)")
        }
    }
}