import Foundation
import SwiftData

@MainActor
final class WatchlistBootstrapService {
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func seedIfNeeded() {
        let hasSeededKey = "kAppHasSeededData_v1"
        guard !UserDefaults.standard.bool(forKey: hasSeededKey) else {
            return
        }
        
        let descriptor = FetchDescriptor<Watchlist>()
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
            do {
                try context.save()
            } catch {
                WatchlistLog.error("Failed to clear watchlists during seeding", error: error)
            }
        }
        
        do {
            try WatchlistSeeder.seed(context: context)
            UserDefaults.standard.set(true, forKey: hasSeededKey)
        } catch {
            WatchlistLog.error("Watchlist seeding failed", error: error)
        }
    }
    
    func performGlobalSeeding() async {
        print("DEBUG performGlobalSeeding: function started")
        do {
            try BirdDatabaseSeeder.shared.seed(modelContext: context)
            await BirdDatabaseSeeder.shared.refreshImageUrls(modelContext: context)
            seedIfNeeded()
            try await HomeDataSeeder.shared.seed(modelContext: context)
        } catch {
            WatchlistLog.error("Global seeding failed", error: error)
        }
    }
    
    func clearUserDataOnLogout(photos: WatchlistPhotoService) async {
        do {
            let watchlists = try context.fetch(FetchDescriptor<Watchlist>())
            for watchlist in watchlists {
                context.delete(watchlist)
            }
            try context.save()
            try? photos.deleteAllLocalPhotos()
            LocationPreferences.shared.clear()
        } catch {
            WatchlistLog.error("Failed to clear user data on logout", error: error)
        }
    }
}
