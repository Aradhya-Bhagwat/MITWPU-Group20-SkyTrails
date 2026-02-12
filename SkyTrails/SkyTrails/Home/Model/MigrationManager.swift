//
//  MigrationManager.swift
//  SkyTrails
//
//  Stub implementation - needs full implementation
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class MigrationManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Get active migrations for a specific week
    func getActiveMigrations(forWeek week: Int) -> [MigrationSession] {
        print("\n🔍 [MigrationManager] getActiveMigrations called")
        print("   📅 Searching for week: \(week)")
        print("   🔎 Predicate: startWeek <= \(week) AND endWeek >= \(week)")
        
        // First, get ALL sessions to debug
        let allDescriptor = FetchDescriptor<MigrationSession>()
        if let allSessions = try? modelContext.fetch(allDescriptor) {
            print("   📊 Total migration sessions in database: \(allSessions.count)")
            for (index, session) in allSessions.enumerated() {
                let birdName = session.bird?.commonName ?? "Unknown Bird"
                let isActive = session.startWeek <= week && session.endWeek >= week
                let status = isActive ? "✅ ACTIVE" : "❌ INACTIVE"
                print("      [\(index)] \(birdName): weeks \(session.startWeek)-\(session.endWeek) \(status)")
            }
        }
        
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.startWeek <= week && session.endWeek >= week
            }
        )
        
        guard let activeSessions = try? modelContext.fetch(descriptor) else {
            print("   ❌ [MigrationManager] Fetch active migrations FAILED")
            return []
        }
        
        if activeSessions.isEmpty {
            print("   ⚠️  [MigrationManager] No active sessions found for week \(week)")
            print("   💡 Tip: Check if migration data was seeded correctly")
        } else {
            print("   ✅ [MigrationManager] Found \(activeSessions.count) active session(s)")
            for session in activeSessions {
                print("      - \(session.bird?.commonName ?? "Unknown")")
            }
        }
        
        return activeSessions
    }
    
    /// Get trajectory data for a session during a specific week
    func getTrajectory(for session: MigrationSession, duringWeek week: Int) -> MigrationTrajectoryResult? {
        // 1. Get paths for this week
        guard let allPaths = session.trajectoryPaths else {
            print("[homeseeder] ❌ [MigrationManager] Session found but trajectoryPaths is nil")
            return nil
        }
        
        let currentPaths = allPaths.filter { $0.week == week }
        
        // 2. Determine most likely position (highest probability)
        let bestPath = currentPaths.max(by: { ($0.probability ?? 0) < ($1.probability ?? 0) })
        let position: CLLocationCoordinate2D?
        if let lat = bestPath?.lat, let lon = bestPath?.lon {
            position = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            position = nil
        }
        
        return MigrationTrajectoryResult(
            session: session,
            pathsAtWeek: currentPaths,
            requestedWeek: week,
            mostLikelyPosition: position
        )
    }

    /// Get trajectory data for a bird during a specific week
    func getTrajectory(for bird: Bird, duringWeek week: Int) -> MigrationTrajectoryResult? {
        // 1. Find session for this bird
        let birdId = bird.id
        print("[homeseeder] 🦅 [MigrationManager] getTrajectory for bird: \(bird.commonName) (Week \(week))")
        
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.bird?.id == birdId &&
                session.startWeek <= week &&
                session.endWeek >= week
            }
        )
        
        guard let session = try? modelContext.fetch(descriptor).first else {
            print("[homeseeder] ❌ [MigrationManager] No session found for bird \(bird.commonName)")
            return nil
        }
        
        return getTrajectory(for: session, duringWeek: week)
    }

    /// Get all migration sessions for a specific bird
    func getSessions(for bird: Bird) -> [MigrationSession] {
        let birdId = bird.id
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.bird?.id == birdId
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
