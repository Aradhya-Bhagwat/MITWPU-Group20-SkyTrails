//
//  HomeDataSeeder.swift
//  SkyTrails
//
//  Created for SkyTrails Home Module Seeding
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
class HomeDataSeeder {
    
    static let shared = HomeDataSeeder()
    
    private init() {}
    
    enum SeederError: Error {
        case fileNotFound
        case dataCorrupted
        case decodingFailed(Error)
    }
    
    func seed(modelContext: ModelContext) async throws {
        // 1. Locate JSON file
        guard let url = Bundle.main.url(forResource: "home_data", withExtension: "json") else {
            return
        }
        
        // 2. Load Data
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SeederError.dataCorrupted
        }
        
        // 3. Decode
        let decoder = JSONDecoder()
        
        let jsonPayload: HomeJSONData
        do {
            jsonPayload = try decoder.decode(HomeJSONData.self, from: data)
        } catch {
            throw SeederError.decodingFailed(error)
        }
        
        // 4. Seed Hotspots
        try await seedHotspots(jsonPayload.hotspots, context: modelContext)
        
        // 5. Seed Migrations
        try await seedMigrations(jsonPayload.migration_sessions, context: modelContext)
        
        // 6. Seed Observations
        try await seedObservations(jsonPayload.community_observations, context: modelContext)
        
        // 7. Save
        try modelContext.save()
    }
    
    // MARK: - Hotspots
    
    private func seedHotspots(_ data: [HotspotData], context: ModelContext) async throws {
        print("[upcomingbirdsdebug] Seeder: Processing \(data.count) hotspots for Recommended Birds data")
        for item in data {
            let id = item.id
            let descriptor = FetchDescriptor<Hotspot>(predicate: #Predicate { $0.id == id })
            let existing = try? context.fetch(descriptor).first
            
            let hotspot: Hotspot
            if let existingHotspot = existing {
                hotspot = existingHotspot
                hotspot.name = item.name
                hotspot.locality = item.locality
                hotspot.lat = item.lat
                hotspot.lon = item.lon
                hotspot.imageName = item.imageName
            } else {
                hotspot = Hotspot(
                    id: item.id,
                    name: item.name,
                    locality: item.locality,
                    lat: item.lat,
                    lon: item.lon,
                    imageName: item.imageName
                )
                context.insert(hotspot)
            }
            
            if let speciesList = item.speciesList {
                for speciesData in speciesList {
                    try seedSpeciesPresence(speciesData, for: hotspot, context: context)
                }
            }
        }
    }
    
    private func seedSpeciesPresence(_ data: SpeciesPresenceData, for hotspot: Hotspot, context: ModelContext) throws {
        let id = data.id
        let descriptor = FetchDescriptor<HotspotSpeciesPresence>(predicate: #Predicate { $0.id == id })
        
        if let existing = try? context.fetch(descriptor).first {
            existing.hotspot = hotspot
            existing.validWeeks = data.validWeeks
            existing.probability = data.probability
            if existing.bird == nil {
                existing.bird = fetchBird(id: data.birdId, context: context)
            }
            if existing.bird == nil {
                print("[upcomingbirdsdebug] ⚠️ Seeder: Bird \(data.birdId) missing. This affects Recommended Birds at \(hotspot.name).")
            }
        } else {
            let bird = fetchBird(id: data.birdId, context: context)
            if bird == nil {
                print("[upcomingbirdsdebug] ⚠️ Seeder: Bird \(data.birdId) missing. This affects Recommended Birds at \(hotspot.name).")
                return
            }
            let presence = HotspotSpeciesPresence(
                id: data.id,
                hotspot: hotspot,
                bird: bird,
                validWeeks: data.validWeeks,
                probability: data.probability
            )
            context.insert(presence)
        }
    }
    
    // MARK: - Migrations
    
    private func seedMigrations(_ data: [MigrationSessionData], context: ModelContext) async throws {
        print("[upcomingbirdsdebug] Seeder: Processing \(data.count) migrations for Upcoming/Prediction data")
        for item in data {
            let id = item.id
            let descriptor = FetchDescriptor<MigrationSession>(predicate: #Predicate { $0.id == id })
            
            let session: MigrationSession
            if let existing = try? context.fetch(descriptor).first {
                session = existing
                session.startWeek = item.startWeek
                session.endWeek = item.endWeek
                session.hemisphere = item.hemisphere
                if session.bird == nil {
                     session.bird = fetchBird(id: item.birdId, context: context)
                }
            } else {
                let bird = fetchBird(id: item.birdId, context: context)
                session = MigrationSession(
                    id: item.id,
                    bird: bird,
                    startWeek: item.startWeek,
                    endWeek: item.endWeek,
                    hemisphere: item.hemisphere
                )
                context.insert(session)
            }
            
            if let paths = item.trajectoryPaths {
                for pathData in paths {
                    try seedTrajectory(pathData, for: session, context: context)
                }
            }
        }
    }
    
    private func seedTrajectory(_ data: TrajectoryPathData, for session: MigrationSession, context: ModelContext) throws {
        let id = data.id
        let descriptor = FetchDescriptor<TrajectoryPath>(predicate: #Predicate { $0.id == id })
        
        if let existing = try? context.fetch(descriptor).first {
            existing.session = session
            existing.week = data.week
            existing.lat = data.lat
            existing.lon = data.lon
            existing.probability = data.probability
        } else {
            let path = TrajectoryPath(
                id: data.id,
                session: session,
                week: data.week,
                lat: data.lat,
                lon: data.lon,
                probability: data.probability
            )
            context.insert(path)
        }
    }
    
    // MARK: - Observations
    
    private func seedObservations(_ data: [CommunityObservationData], context: ModelContext) async throws {
        let formatter = ISO8601DateFormatter()
        
        for item in data {
            let id = item.id
            let descriptor = FetchDescriptor<CommunityObservation>(predicate: #Predicate { $0.id == id })
            
            let date = formatter.date(from: item.observedAt) ?? Date()
            
            if let existing = try? context.fetch(descriptor).first {
                existing.username = item.username
                existing.userAvatar = item.userAvatar
                existing.observationTitle = item.observationTitle
                existing.location = item.location
                existing.lat = item.lat
                existing.lon = item.lon
                existing.observedAt = date
                existing.likesCount = item.likesCount
                existing.imageName = item.imageName
                existing.birdName = item.birdName
            } else {
                let observation = CommunityObservation(
                    id: item.id,
                    username: item.username,
                    userAvatar: item.userAvatar,
                    observationTitle: item.observationTitle,
                    location: item.location,
                    lat: item.lat,
                    lon: item.lon,
                    observedAt: date,
                    likesCount: item.likesCount,
                    imageName: item.imageName,
                    birdName: item.birdName
                )
                context.insert(observation)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func fetchBird(id: UUID, context: ModelContext) -> Bird? {
        let descriptor = FetchDescriptor<Bird>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
