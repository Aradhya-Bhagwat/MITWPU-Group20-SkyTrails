	//
	//  ViewModel.swift
	//  SkyTrails
	//

import Foundation

class WatchlistViewModel {
	
	var watchlists: [Watchlist] = []
    var sharedWatchlists: [SharedWatchlist] = []
	
	init() {
        loadData()
        
        // Only seed mock data if the file DOES NOT EXIST.
        // If file exists but loadData failed (decoding error), watchlists is empty,
        // but we MUST NOT overwrite the file with mocks.
        let watchlistsURL = getDocumentsDirectory().appendingPathComponent("watchlists.json")
        let fileExists = FileManager.default.fileExists(atPath: watchlistsURL.path)
        
        if self.watchlists.isEmpty && !fileExists {
            print("🌱 Seeding Mock Data (First Run)")
            self.watchlists = createMockWatchlists()
            
            // Helper to get some random birds from mock watchlists
            // Ensure we have enough birds for distinct lists
            let allBirds = self.watchlists.flatMap { $0.birds }
            
            // Split birds to ensure distinct observed and toObserve lists for shared watchlists
            let firstHalf = Array(allBirds.prefix(allBirds.count / 2)) // First half
            let secondHalf = Array(allBirds.suffix(allBirds.count - firstHalf.count)) // Second half
            
            self.sharedWatchlists = [
                SharedWatchlist(
                    title: "Canopy Wanderers",
                    location: "Vetal tekdi",
                    dateRange: "8th Oct - 7th Nov",
                    mainImageName: "AsianFairyBluebird",
                    stats: SharedWatchlistStats(greenValue: 18, blueValue: 7),
                    userImages: ["person.crop.circle.fill", "person.crop.circle", "person.circle.fill", "person.crop.circle.fill", "person.crop.circle"],
                    observedBirds: Array(firstHalf.prefix(max(1, firstHalf.count / 2))), // At least one bird observed
                    toObserveBirds: Array(firstHalf.suffix(max(1, firstHalf.count - firstHalf.count / 2))) // At least one bird to observe
                ),
                SharedWatchlist(
                    title: "Feather Trail",
                    location: "Singhad Valley",
                    dateRange: "12th Oct - 15th Nov",
                    mainImageName: "HimalayanMonal",
                    stats: SharedWatchlistStats(greenValue: 10, blueValue: 2),
                    userImages: ["person.circle.fill", "person.crop.circle", "person.crop.circle.fill", "person.crop.circle"],
                    observedBirds: Array(secondHalf.prefix(max(1, secondHalf.count / 2))), // At least one bird observed
                    toObserveBirds: Array(secondHalf.suffix(max(1, secondHalf.count - secondHalf.count / 2))) // At least one bird to observe
                )
            ]
            saveData()
        }
    }

    
    // MARK: - Persistence
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveData() {
        let watchlistsURL = getDocumentsDirectory().appendingPathComponent("watchlists.json")
        let sharedWatchlistsURL = getDocumentsDirectory().appendingPathComponent("sharedWatchlists.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            let watchlistsData = try encoder.encode(watchlists)
            try watchlistsData.write(to: watchlistsURL)
            
            let sharedData = try encoder.encode(sharedWatchlists)
            try sharedData.write(to: sharedWatchlistsURL)
            
        } catch {
            print("Error saving data: \(error)")
        }
    }
    
    private func loadData() {
        let watchlistsURL = getDocumentsDirectory().appendingPathComponent("watchlists.json")
        let sharedWatchlistsURL = getDocumentsDirectory().appendingPathComponent("sharedWatchlists.json")
        
        let decoder = JSONDecoder()
        
        // Load Custom Watchlists
        if let data = try? Data(contentsOf: watchlistsURL) {
            do {
                let decoded = try decoder.decode([Watchlist].self, from: data)
                self.watchlists = decoded
            } catch {
                print("❌ CRITICAL ERROR: Failed to decode watchlists.json: \(error)")
                // Do NOT overwrite with mock data here. Let it fail safely so user knows something is wrong
                // or at least doesn't save over it immediately.
            }
        } else {
             print("ℹ️ No watchlists.json found (Fresh install?)")
        }
        
        // Load Shared Watchlists
        if let data = try? Data(contentsOf: sharedWatchlistsURL) {
            do {
                let decoded = try decoder.decode([SharedWatchlist].self, from: data)
                self.sharedWatchlists = decoded
            } catch {
                 print("❌ CRITICAL ERROR: Failed to decode sharedWatchlists.json: \(error)")
            }
        }
    }

	
		// MARK: - Calculated Stats for Summary Cards
	
		// 1. Total number of birds across all watchlists
	var totalSpeciesCount: Int {
		return watchlists.reduce(0) { $0 + $1.birds.count }
	}
	
		// 2. Total number of observed birds across all watchlists
	var totalObservedCount: Int {
		return watchlists.reduce(0) { $0 + $1.observedCount }
	}
	
		// 3. Total number of rare birds across all watchlists
	var totalRareCount: Int {
		return watchlists.reduce(0) { currentTotal, watchlist in
			let rareInThisList = watchlist.birds.filter { bird in
				bird.rarity.contains(.rare)
			}.count
			return currentTotal + rareInThisList
		}
	}
    
    func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) {
        if let index = watchlists.firstIndex(where: { $0.id == watchlistId }) {
            if asObserved {
                watchlists[index].observedBirds.append(contentsOf: birds)
            } else {
                watchlists[index].toObserveBirds.append(contentsOf: birds)
            }
        } else if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
            if asObserved {
                sharedWatchlists[index].observedBirds.append(contentsOf: birds)
            } else {
                sharedWatchlists[index].toObserveBirds.append(contentsOf: birds)
            }
        }
        saveData()
    }
    
    func deleteBird(_ bird: Bird, from watchlistId: UUID) {
        if let index = watchlists.firstIndex(where: { $0.id == watchlistId }) {
            if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].observedBirds.remove(at: birdIndex)
            } else if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].toObserveBirds.remove(at: birdIndex)
            }
        } else if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
            if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].observedBirds.remove(at: birdIndex)
            } else if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].toObserveBirds.remove(at: birdIndex)
            }
        }
        saveData()
    }
    
    func saveObservation(bird: Bird, watchlistId: UUID) {
        // 1. Check My Watchlists
        if let index = watchlists.firstIndex(where: { $0.id == watchlistId }) {
            // Case A: Update existing Observed
            if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].observedBirds[birdIndex] = bird
            }
            // Case B: Move from To Observe -> Observed
            else if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].toObserveBirds.remove(at: birdIndex)
                watchlists[index].observedBirds.append(bird)
            }
            // Case C: New Observation
            else {
                watchlists[index].observedBirds.append(bird)
            }
        }
        // 2. Check Shared Watchlists
        else if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
            // Case A: Update existing Observed
            if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].observedBirds[birdIndex] = bird
            }
            // Case B: Move from To Observe -> Observed
            else if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].toObserveBirds.remove(at: birdIndex)
                sharedWatchlists[index].observedBirds.append(bird)
            }
            // Case C: New Observation
            else {
                sharedWatchlists[index].observedBirds.append(bird)
            }
        }
        saveData()
    }
    
    func updateBird(_ bird: Bird, watchlistId: UUID) {
         // 1. Check My Watchlists
         if let index = watchlists.firstIndex(where: { $0.id == watchlistId }) {
             if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                 watchlists[index].observedBirds[birdIndex] = bird
             } else if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                 watchlists[index].toObserveBirds[birdIndex] = bird
             }
         }
         // 2. Check Shared Watchlists
         else if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
             if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                 sharedWatchlists[index].observedBirds[birdIndex] = bird
             } else if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                 sharedWatchlists[index].toObserveBirds[birdIndex] = bird
             }
         }
         saveData()
    }
    
    // MARK: - Watchlist Management
    
    func deleteWatchlist(id: UUID) {
        if let index = watchlists.firstIndex(where: { $0.id == id }) {
            watchlists.remove(at: index)
            saveData()
        }
    }
    
    func deleteSharedWatchlist(id: UUID) {
        if let index = sharedWatchlists.firstIndex(where: { $0.id == id }) {
            sharedWatchlists.remove(at: index)
            saveData()
        }
    }
    
    func updateWatchlist(id: UUID, title: String, location: String, startDate: Date, endDate: Date) {
        if let index = watchlists.firstIndex(where: { $0.id == id }) {
            watchlists[index].title = title
            watchlists[index].location = location
            watchlists[index].startDate = startDate
            watchlists[index].endDate = endDate
            saveData()
        }
    }
    
    func updateSharedWatchlist(id: UUID, title: String, location: String, dateRange: String) {
        if let index = sharedWatchlists.firstIndex(where: { $0.id == id }) {
            sharedWatchlists[index].title = title
            sharedWatchlists[index].location = location
            sharedWatchlists[index].dateRange = dateRange
            saveData()
        }
    }
    
    func addWatchlist(_ watchlist: Watchlist) {
        watchlists.append(watchlist)
        saveData()
    }
    
    func addSharedWatchlist(_ watchlist: SharedWatchlist) {
        sharedWatchlists.append(watchlist)
        saveData()
    }
}
