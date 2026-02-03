//
//  WatchlistSeeder.swift
//  SkyTrails
//
//  Created by SDC-USER on 02/02/26.
//

import Foundation
import SwiftData

struct WatchlistSeeder {
    
    // Define DTOs privately here to keep global namespace clean
    private struct JSONWatchlistDTO: Codable {
        let id: UUID
        let title: String
        let location: String
        let startDate: TimeInterval
        let endDate: TimeInterval
        let observedBirds: [JSONBirdDTO]
        let toObserveBirds: [JSONBirdDTO]
        let mainImageName: String?
    }

    private struct JSONSharedWatchlistDTO: Codable {
        let id: UUID
        let title: String
        let location: String
        let dateRange: String
        let startDate: TimeInterval?
        let endDate: TimeInterval?
        let mainImageName: String?
        let stats: JSONSharedStatsDTO
        let userImages: [String]
        let observedBirds: [JSONBirdDTO]
        let toObserveBirds: [JSONBirdDTO]
    }

    private struct JSONSharedStatsDTO: Codable {
        let greenValue: Int
        let blueValue: Int
    }

    private struct JSONBirdDTO: Codable {
        let id: UUID
        let name: String
        let scientificName: String
        let images: [String]
        let rarity: [String]
        let location: [String]
        let date: [TimeInterval]
        let observedBy: [String]?
    }
    
    // MARK: - Public API
    
    /// Checks if seeding is required and performs it.
    @MainActor
    static func seed(context: ModelContext) throws {
        print("🌱 [WatchlistSeeder] Starting seed check...")
        
        // 1. Check if data exists
        let descriptor = FetchDescriptor<Watchlist>()
        let count = try context.fetchCount(descriptor)
        
        guard count == 0 else {
            print("✅ [WatchlistSeeder] Database already populated with \(count) watchlists. Skipping seed.")
            return
        }
        
        print("📦 [WatchlistSeeder] Database empty. Starting seed...")
        
        // 2. Load and Insert Custom Watchlists
        do {
            try seedCustomWatchlists(context: context)
            print("✅ [WatchlistSeeder] Custom watchlists seeded successfully")
        } catch {
            print("❌ [WatchlistSeeder] Failed to seed custom watchlists: \(error)")
            throw SeederError.seedingFailed("Custom watchlists", error)
        }
        
        // 3. Load and Insert Shared Watchlists
        do {
            try seedSharedWatchlists(context: context)
            print("✅ [WatchlistSeeder] Shared watchlists seeded successfully")
        } catch {
            print("❌ [WatchlistSeeder] Failed to seed shared watchlists: \(error)")
            throw SeederError.seedingFailed("Shared watchlists", error)
        }
        
        // 4. Save
        do {
            try context.save()
            print("💾 [WatchlistSeeder] Context saved successfully")
        } catch {
            print("❌ [WatchlistSeeder] Failed to save context: \(error)")
            throw SeederError.saveFailed(error)
        }
        
        // 5. Verify seeding
        let finalCount = try context.fetchCount(descriptor)
        print("✅ [WatchlistSeeder] Seeding complete. Total watchlists: \(finalCount)")
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private static func seedCustomWatchlists(context: ModelContext) throws {
        print("📖 [WatchlistSeeder] Loading watchlists.json...")
        
        guard let url = Bundle.main.url(forResource: "watchlists", withExtension: "json") else {
            print("❌ [WatchlistSeeder] watchlists.json not found in bundle")
            throw SeederError.fileNotFound("watchlists.json")
        }
        
        print("📄 [WatchlistSeeder] Found watchlists.json at: \(url.path)")
        
        let data = try Data(contentsOf: url)
        print("📦 [WatchlistSeeder] Loaded \(data.count) bytes from watchlists.json")
        
        let dtos = try JSONDecoder().decode([JSONWatchlistDTO].self, from: data)
        print("✅ [WatchlistSeeder] Decoded \(dtos.count) watchlists from JSON")
        
        for (index, dto) in dtos.enumerated() {
            print("  ➤ Processing watchlist \(index + 1)/\(dtos.count): '\(dto.title)'")
            
            // Special handling for "My Watchlist"
            let type: WatchlistType = (dto.title == "My Watchlist") ? .my_watchlist : .custom
            
            let watchlist = Watchlist(
                id: dto.id,
                type: type,
                title: dto.title,
                location: dto.location,
                startDate: Date(timeIntervalSinceReferenceDate: dto.startDate),
                endDate: Date(timeIntervalSinceReferenceDate: dto.endDate)
            )
            
            if let img = dto.mainImageName {
                let image = WatchlistImage(watchlist: watchlist, imagePath: img)
                context.insert(image)
                print("    🖼️  Added image: \(img)")
            }
            
            context.insert(watchlist)
            
            let observedCount = dto.observedBirds.count
            let toObserveCount = dto.toObserveBirds.count
            print("    🐦 Processing \(observedCount) observed + \(toObserveCount) to-observe birds")
            
            processBirds(dto.observedBirds, for: watchlist, status: .observed, context: context)
            processBirds(dto.toObserveBirds, for: watchlist, status: .to_observe, context: context)
        }
    }
    
    @MainActor
    private static func seedSharedWatchlists(context: ModelContext) throws {
        print("📖 [WatchlistSeeder] Loading sharedWatchlists.json...")
        
        guard let url = Bundle.main.url(forResource: "sharedWatchlists", withExtension: "json") else {
            print("❌ [WatchlistSeeder] sharedWatchlists.json not found in bundle")
            throw SeederError.fileNotFound("sharedWatchlists.json")
        }
        
        print("📄 [WatchlistSeeder] Found sharedWatchlists.json at: \(url.path)")
        
        let data = try Data(contentsOf: url)
        print("📦 [WatchlistSeeder] Loaded \(data.count) bytes from sharedWatchlists.json")
        
        let dtos = try JSONDecoder().decode([JSONSharedWatchlistDTO].self, from: data)
        print("✅ [WatchlistSeeder] Decoded \(dtos.count) shared watchlists from JSON")
        
        for (index, dto) in dtos.enumerated() {
            print("  ➤ Processing shared watchlist \(index + 1)/\(dtos.count): '\(dto.title)'")
            
            let watchlist = Watchlist(
                id: dto.id,
                type: .shared,
                title: dto.title,
                location: dto.location,
                startDate: dto.startDate.map { Date(timeIntervalSinceReferenceDate: $0) },
                endDate: dto.endDate.map { Date(timeIntervalSinceReferenceDate: $0) }
            )
            
            if let imageName = dto.mainImageName {
                let image = WatchlistImage(watchlist: watchlist, imagePath: imageName)
                context.insert(image)
                print("    🖼️  Added image: \(imageName)")
            }
            
            context.insert(watchlist)
            
            let observedCount = dto.observedBirds.count
            let toObserveCount = dto.toObserveBirds.count
            print("    🐦 Processing \(observedCount) observed + \(toObserveCount) to-observe birds")
            
            processBirds(dto.observedBirds, for: watchlist, status: .observed, context: context)
            processBirds(dto.toObserveBirds, for: watchlist, status: .to_observe, context: context)
        }
    }
    
    @MainActor
    private static func processBirds(_ birdDTOs: [JSONBirdDTO], for watchlist: Watchlist, status: WatchlistEntryStatus, context: ModelContext) {
        for dto in birdDTOs {
            // Find or Create Bird (Avoid duplicates)
            let bird = findOrCreateBird(from: dto, in: context)
            
            let entry = WatchlistEntry(
                watchlist: watchlist,
                bird: bird,
                status: status,
                observedBy: dto.observedBy?.first // Simplification for now
            )
            
            if status == .observed, let dateInterval = dto.date.first {
                entry.observationDate = Date(timeIntervalSinceReferenceDate: dateInterval)
            }
            
            context.insert(entry)
        }
    }
    
    @MainActor
    private static func findOrCreateBird(from dto: JSONBirdDTO, in context: ModelContext) -> Bird {
        // Efficient fetch by ID
        let id = dto.id
        let descriptor = FetchDescriptor<Bird>(predicate: #Predicate<Bird> { bird in
            bird.id == id
        })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Map Rarity String to Enum
        let rarityString = dto.rarity.first?.lowercased() ?? "common"
        let rarity: BirdRarityLevel = (rarityString == "rare") ? .rare : (rarityString == "very_rare" ? .very_rare : .common)
        
        let newBird = Bird(
            id: dto.id,
            commonName: dto.name,
            scientificName: dto.scientificName,
            staticImageName: dto.images.first ?? "placeholder",
            rarityLevel: rarity,
            validLocations: dto.location
        )
        context.insert(newBird)
        return newBird
    }
    
    enum SeederError: Error, LocalizedError {
        case fileNotFound(String)
        case seedingFailed(String, Error)
        case saveFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "Seed file not found: \(filename)"
            case .seedingFailed(let type, let error):
                return "Failed to seed \(type): \(error.localizedDescription)"
            case .saveFailed(let error):
                return "Failed to save seeded data: \(error.localizedDescription)"
            }
        }
    }
}

