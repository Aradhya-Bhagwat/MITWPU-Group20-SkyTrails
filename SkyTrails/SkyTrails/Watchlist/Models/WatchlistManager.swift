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
        
        // Only seed mock data if the file DOES NOT EXIST.
        let watchlistsURL = getDocumentsDirectory().appendingPathComponent("watchlists.json")
        let fileExists = FileManager.default.fileExists(atPath: watchlistsURL.path)
        
        if self.watchlists.isEmpty && !fileExists {
            print("🌱 Seeding Mock Data (First Run)")
            self.watchlists = createMockWatchlists()
            
            let allBirds = self.watchlists.flatMap { $0.birds }
            let firstHalf = Array(allBirds.prefix(allBirds.count / 2))
            let secondHalf = Array(allBirds.suffix(allBirds.count - firstHalf.count))
            
            self.sharedWatchlists = [
                SharedWatchlist(
                    title: "Canopy Wanderers",
                    location: "Vetal tekdi",
                    dateRange: "8th Oct - 7th Nov",
                    mainImageName: "AsianFairyBluebird",
                    stats: SharedWatchlistStats(greenValue: 18, blueValue: 7),
                    userImages: ["person.crop.circle.fill", "person.crop.circle", "person.circle.fill", "person.crop.circle.fill", "person.crop.circle"],
                    observedBirds: Array(firstHalf.prefix(max(1, firstHalf.count / 2))),
                    toObserveBirds: Array(firstHalf.suffix(max(1, firstHalf.count - firstHalf.count / 2)))
                ),
                SharedWatchlist(
                    title: "Feather Trail",
                    location: "Singhad Valley",
                    dateRange: "12th Oct - 15th Nov",
                    mainImageName: "HimalayanMonal",
                    stats: SharedWatchlistStats(greenValue: 10, blueValue: 2),
                    userImages: ["person.circle.fill", "person.crop.circle", "person.crop.circle.fill", "person.crop.circle"],
                    observedBirds: Array(secondHalf.prefix(max(1, secondHalf.count / 2))),
                    toObserveBirds: Array(secondHalf.suffix(max(1, secondHalf.count - secondHalf.count / 2)))
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
    
    public func loadData() {
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
    
    // MARK: - Mock Data Helper
    private func createMockWatchlists() -> [Watchlist] {
        // Embed the mock data generation here or call the separate file if preferred.
        // For simplicity and cleaner MVC, I'll inline the helper functions or expect them to be available.
        // Assuming 'MockData.swift' contents are moved here or accessible.
        // Since MockData.swift was a global function, it's accessible.
        // But to be self contained, I will assume the global function `createMockWatchlists()` exists
        // or I should move it here.
        // The instruction says "Merge...".
        // I will trust the global function `createMockWatchlists` exists in the project context for now,
        // or I'll copy the body if I delete the file later.
        // Since I plan to delete MockData.swift later, I should copy the logic here.
        
        func randomDate(daysBack: Int) -> Date {
            return Date().addingTimeInterval(-Double(Int.random(in: 0...daysBack)) * 86400)
        }
        
        let bird1 = Bird(name: "Himalayan Monal", scientificName: "Lophophorus impejanus", images: ["HimalayanMonal"], rarity: [.rare], location: ["Kathmandu, Nepal"], date: [randomDate(daysBack: 10)], observedBy: ["person.circle", "person.fill"])
        let bird2 = Bird(name: "Asian Koel", scientificName: "Eudynamys scolopaceus", images: ["AsianKoel"], rarity: [.common], location: ["Pune, Maharashtra"], date: [randomDate(daysBack: 2)], observedBy: ["person.2.circle"])
        let bird3 = Bird(name: "Indian Peafowl", scientificName: "Pavo cristatus", images: ["IndianPeafowl"], rarity: [.common], location: ["Mumbai, Maharashtra"], date: [randomDate(daysBack: 5)], observedBy: nil)
        let bird4 = Bird(name: "Great Hornbill", scientificName: "Buceros bicornis", images: ["GreatHornbill"], rarity: [.rare], location: ["Munnar, Kerala"], date: [randomDate(daysBack: 15)], observedBy: ["person.crop.circle.fill"])
        let bird5 = Bird(name: "Oriental Magpie-Robin", scientificName: "Copsychus saularis", images: ["OrientalMagpieRobin"], rarity: [.common], location: ["New Delhi, India"], date: [randomDate(daysBack: 1)], observedBy: ["person.crop.circle", "person.circle.fill", "person.circle"])
        let bird6 = Bird(name: "Greater Flameback", scientificName: "Chrysocolaptes lucidus", images: ["GreaterFlameback"], rarity: [.rare], location: ["Panaji, Goa"], date: [randomDate(daysBack: 8)], observedBy: nil)
        let bird7 = Bird(name: "Sarus Crane", scientificName: "Antigone antigone", images: ["SarusCrane"], rarity: [.common], location: ["Agra, Uttar Pradesh"], date: [randomDate(daysBack: 3)], observedBy: ["person.fill"])
        let bird8 = Bird(name: "Blue Grosbeak", scientificName: "Passerina caerulea", images: ["BlueGrosbeak"], rarity: [.rare], location: ["Texas, USA"], date: [randomDate(daysBack: 20)], observedBy: ["person.3.fill"])
        let bird9 = Bird(name: "Indigo Bunting", scientificName: "Passerina cyanea", images: ["IndigoBunting"], rarity: [.common], location: ["New York, USA"], date: [randomDate(daysBack: 7)], observedBy: ["person.circle"])
        let bird10 = Bird(name: "Lazuli Bunting", scientificName: "Passerina amoena", images: ["LazuliBunting"], rarity: [.rare], location: ["Colorado, USA"], date: [randomDate(daysBack: 12)], observedBy: ["person.crop.circle.badge.plus"])
        
        let watchlist1 = Watchlist(title: "My Watchlist", location: "Home", startDate: Date(), endDate: Date(), observedBirds: [bird1, bird3, bird5], toObserveBirds: [bird2, bird7])
        let watchlist2 = Watchlist(title: "Jungle Safari", location: "National Park", startDate: Date().addingTimeInterval(-86400 * 30), endDate: Date().addingTimeInterval(-86400 * 20), observedBirds: [bird4, bird6], toObserveBirds: [bird8])
        let watchlist3 = Watchlist(title: "Himalayan Expedition", location: "Himalayas", startDate: Date().addingTimeInterval(-86400 * 60), endDate: Date().addingTimeInterval(-86400 * 45), observedBirds: [bird1, bird9], toObserveBirds: [bird4, bird10])
        let watchlist4 = Watchlist(title: "Backyard Birds", location: "My Garden", startDate: Date().addingTimeInterval(-86400 * 10), endDate: Date(), observedBirds: [bird2, bird7], toObserveBirds: [bird3, bird8])
        let watchlist5 = Watchlist(title: "Tropical Forest", location: "Amazon", startDate: Date().addingTimeInterval(-86400 * 90), endDate: Date().addingTimeInterval(-86400 * 70), observedBirds: [bird3, bird9], toObserveBirds: [bird6, bird10])
        let watchlist6 = Watchlist(title: "Desert Birds", location: "Thar Desert", startDate: Date().addingTimeInterval(-86400 * 5), endDate: Date().addingTimeInterval(-86400 * 1), observedBirds: [bird8, bird10], toObserveBirds: [bird1, bird2])
        
        return [watchlist1, watchlist2, watchlist3, watchlist4, watchlist5, watchlist6]
    }
}
