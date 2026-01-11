//
//  WatchlistManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 15/12/25.
//

import Foundation
import CoreLocation

class WatchlistManager {
    
    static let shared = WatchlistManager()
    
    var watchlists: [Watchlist] = []
    var sharedWatchlists: [SharedWatchlist] = []
    
    private init() {
        loadData()
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
    
    public func loadData() {
        let watchlistsURL = getDocumentsDirectory().appendingPathComponent("watchlists.json")
        let sharedWatchlistsURL = getDocumentsDirectory().appendingPathComponent("sharedWatchlists.json")
        
        let decoder = JSONDecoder()
        var loadedWatchlists = false
        var loadedShared = false
        
        // 1. Load Custom Watchlists
        if let data = try? Data(contentsOf: watchlistsURL) {
            do {
                let decoded = try decoder.decode([Watchlist].self, from: data)
                self.watchlists = decoded
                loadedWatchlists = true
            } catch {
                print("CRITICAL ERROR: Failed to decode watchlists.json from Documents: \(error)")
            }
        }
        
        // Fallback: Load from Bundle if not in Documents
        if !loadedWatchlists {
            if let bundleURL = Bundle.main.url(forResource: "watchlists", withExtension: "json"),
               let data = try? Data(contentsOf: bundleURL) {
                do {
                    let decoded = try decoder.decode([Watchlist].self, from: data)
                    self.watchlists = decoded
                    loadedWatchlists = true
                } catch {
                     print("CRITICAL ERROR: Failed to decode watchlists.json from Bundle: \(error)")
                }
            }
        }

        // 2. Load Shared Watchlists
        if let data = try? Data(contentsOf: sharedWatchlistsURL) {
            do {
                let decoded = try decoder.decode([SharedWatchlist].self, from: data)
                self.sharedWatchlists = decoded
                loadedShared = true
            } catch {
                 print("CRITICAL ERROR: Failed to decode sharedWatchlists.json from Documents: \(error)")
            }
        }
        
        // Fallback: Load from Bundle
        if !loadedShared {
            if let bundleURL = Bundle.main.url(forResource: "sharedWatchlists", withExtension: "json"),
               let data = try? Data(contentsOf: bundleURL) {
                do {
                    let decoded = try decoder.decode([SharedWatchlist].self, from: data)
                    self.sharedWatchlists = decoded
                    loadedShared = true
                } catch {
                     print("CRITICAL ERROR: Failed to decode sharedWatchlists.json from Bundle: \(error)")
                }
            }
        }
        
        // If we loaded from Bundle, save to Documents so user edits are persisted
        // (Only save if we actually have data to save, to avoid empty file creation if not needed)
        if !self.watchlists.isEmpty || !self.sharedWatchlists.isEmpty {
             saveData()
        }
    }


    // MARK: - Calculated Stats for Summary Cards
    
    var totalSpeciesCount: Int {
        return watchlists.reduce(0) { $0 + $1.birds.count }
    }
    
    var totalObservedCount: Int {
        return watchlists.reduce(0) { $0 + $1.observedCount }
    }
    
    var totalRareCount: Int {
        return watchlists.reduce(0) { currentTotal, watchlist in
            let rareInThisList = watchlist.birds.filter { bird in
                bird.rarity.contains(.rare)
            }.count
            return currentTotal + rareInThisList
        }
    }
    
    // MARK: - CRUD
    
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
    
    
    
    // Extension for adding specific birds by request
    
    extension WatchlistManager {
    
        func addRoseRingedParakeetToMyWatchlist() {
    
            // Find "My Watchlist"
    
            guard let myWatchlistIndex = watchlists.firstIndex(where: { $0.title == "My Watchlist" }) else {
    
                print("Error: 'My Watchlist' not found.")
    
                return
    
            }
    
    
    
            // Create the Rose-ringed Parakeet bird object
    
            let roseRingedParakeet = Bird(
    
                id: UUID(),
    
                name: "Rose-ringed Parakeet",
    
                scientificName: "Psittacula krameri",
    
                images: ["rose_ringed_parakeet"],
    
                rarity: [.common],
    
                location: ["Pune, India"], // Example location
    
                date: [Date()], // Current date
    
                observedBy: nil,
    
                notes: "Added by user request."
    
            )
    
    
    
            // Add to 'toObserveBirds'
    
            watchlists[myWatchlistIndex].toObserveBirds.append(roseRingedParakeet)
    
            saveData()
    
            print("Rose-ringed Parakeet added to 'My Watchlist' successfully.")
    
        }
    
    }
