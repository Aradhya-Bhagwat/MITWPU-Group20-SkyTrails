//
//  WatchlistManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 15/12/25.
//

import Foundation
import CoreLocation

final class WatchlistManager {
    
    static let shared = WatchlistManager()
    
    private(set) var watchlists: [Watchlist] = []
    private(set) var sharedWatchlists: [SharedWatchlist] = []
    
    private let queue = DispatchQueue(label: "com.skytrails.watchlistmanager", qos: .userInitiated)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var isDataLoaded = false
    private var loadCompletionHandlers: [(Bool) -> Void] = []
    
    static let didLoadDataNotification = Notification.Name("WatchlistManagerDidLoadData")
    
    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        decoder = JSONDecoder()
        loadData()
    }
    
    func onDataLoaded(_ handler: @escaping (Bool) -> Void) {
        if isDataLoaded {
            handler(isDataLoaded)
        } else {
            loadCompletionHandlers.append(handler)
        }
    }
    
    private func notifyDataLoaded(success: Bool) {
        isDataLoaded = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.post(
                name: WatchlistManager.didLoadDataNotification,
                object: self,
                userInfo: ["success": success]
            )
            self.loadCompletionHandlers.forEach { $0(success) }
            self.loadCompletionHandlers.removeAll()
        }
    }
    
    // MARK: - Persistence
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let watchlistsURL = self.getDocumentsDirectory().appendingPathComponent("watchlists.json")
            let sharedWatchlistsURL = self.getDocumentsDirectory().appendingPathComponent("sharedWatchlists.json")
            
            do {
                let watchlistsData = try self.encoder.encode(self.watchlists)
                try watchlistsData.write(to: watchlistsURL, options: .atomic)
                
                let sharedData = try self.encoder.encode(self.sharedWatchlists)
                try sharedData.write(to: sharedWatchlistsURL, options: .atomic)
            } catch {
                print("Error saving data: \(error)")
            }
        }
    }
    
    private func loadData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let watchlistsURL = self.getDocumentsDirectory().appendingPathComponent("watchlists.json")
            let sharedWatchlistsURL = self.getDocumentsDirectory().appendingPathComponent("sharedWatchlists.json")
            
            let loadedWatchlists = self.loadWatchlists(from: watchlistsURL, fallbackBundle: "watchlists")
            let loadedShared = self.loadSharedWatchlists(from: sharedWatchlistsURL, fallbackBundle: "sharedWatchlists")
            
            DispatchQueue.main.async {
                let hasData = !loadedWatchlists.watchlists.isEmpty || !loadedShared.watchlists.isEmpty
                self.watchlists = loadedWatchlists.watchlists
                self.sharedWatchlists = loadedShared.watchlists
                
                if loadedWatchlists.wasLoadedFromBundle || loadedShared.wasLoadedFromBundle {
                    self.saveData()
                }
                
                self.notifyDataLoaded(success: hasData)
            }
        }
    }
    
    private func loadWatchlists(from documentsURL: URL, fallbackBundle bundleName: String) -> (watchlists: [Watchlist], wasLoadedFromBundle: Bool) {
        if let data = try? Data(contentsOf: documentsURL) {
            do {
                let decoded = try self.decoder.decode([Watchlist].self, from: data)
                return (decoded, false)
            } catch {
                print("CRITICAL ERROR: Failed to decode watchlists.json from Documents: \(error)")
            }
        }
        
        if let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL) {
            do {
                let decoded = try self.decoder.decode([Watchlist].self, from: data)
                print("Loaded watchlists from Bundle as fallback")
                return (decoded, true)
            } catch {
                print("CRITICAL ERROR: Failed to decode watchlists.json from Bundle: \(error)")
            }
        }
        
        return ([], false)
    }
    
    private func loadSharedWatchlists(from documentsURL: URL, fallbackBundle bundleName: String) -> (watchlists: [SharedWatchlist], wasLoadedFromBundle: Bool) {
        if let data = try? Data(contentsOf: documentsURL) {
            do {
                let decoded = try self.decoder.decode([SharedWatchlist].self, from: data)
                return (decoded, false)
            } catch {
                print("CRITICAL ERROR: Failed to decode sharedWatchlists.json from Documents: \(error)")
            }
        }
        
        if let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL) {
            do {
                let decoded = try self.decoder.decode([SharedWatchlist].self, from: data)
                print("Loaded shared watchlists from Bundle as fallback")
                return (decoded, true)
            } catch {
                print("CRITICAL ERROR: Failed to decode sharedWatchlists.json from Bundle: \(error)")
            }
        }
        
        return ([], false)
    }
    
    // MARK: - Helper Methods
    
    private func findWatchlistIndex(id: UUID) -> (type: WatchlistType, index: Int)? {
        if let index = watchlists.firstIndex(where: { $0.id == id }) {
            return (.custom, index)
        }
        if let index = sharedWatchlists.firstIndex(where: { $0.id == id }) {
            return (.shared, index)
        }
        return nil
    }
    
    private enum WatchlistType {
        case custom
        case shared
    }
    
    // MARK: - Data Access (Thread-safe)
    
    func getWatchlist(by id: UUID) -> Watchlist? {
        watchlists.first { $0.id == id }
    }
    
    func getSharedWatchlist(by id: UUID) -> SharedWatchlist? {
        sharedWatchlists.first { $0.id == id }
    }
    
    // MARK: - Calculated Stats
    
    var totalSpeciesCount: Int {
        watchlists.reduce(0) { $0 + $1.birds.count }
    }
    
    var totalObservedCount: Int {
        watchlists.reduce(0) { $0 + $1.observedCount }
    }
    
    var totalRareCount: Int {
        watchlists.reduce(0) { total, watchlist in
            let rareCount = watchlist.birds.filter { $0.rarity.contains(.rare) }.count
            return total + rareCount
        }
    }
    
    // MARK: - CRUD Operations
    
    func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) {
        guard let (type, index) = findWatchlistIndex(id: watchlistId) else { return }
        
        switch type {
        case .custom:
            if asObserved {
                watchlists[index].observedBirds.append(contentsOf: birds)
            } else {
                watchlists[index].toObserveBirds.append(contentsOf: birds)
            }
        case .shared:
            if asObserved {
                sharedWatchlists[index].observedBirds.append(contentsOf: birds)
            } else {
                sharedWatchlists[index].toObserveBirds.append(contentsOf: birds)
            }
        }
        saveData()
    }
    
    func deleteBird(_ bird: Bird, from watchlistId: UUID) {
        guard let (type, index) = findWatchlistIndex(id: watchlistId) else { return }
        
        switch type {
        case .custom:
            if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].observedBirds.remove(at: birdIndex)
            } else if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].toObserveBirds.remove(at: birdIndex)
            }
        case .shared:
            if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].observedBirds.remove(at: birdIndex)
            } else if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].toObserveBirds.remove(at: birdIndex)
            }
        }
        saveData()
    }
    
    func saveObservation(bird: Bird, watchlistId: UUID) {
        guard let (type, index) = findWatchlistIndex(id: watchlistId) else { return }
        
        switch type {
        case .custom:
            if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].observedBirds[birdIndex] = bird
            } else if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].toObserveBirds.remove(at: birdIndex)
                watchlists[index].observedBirds.append(bird)
            } else {
                watchlists[index].observedBirds.append(bird)
            }
        case .shared:
            if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].observedBirds[birdIndex] = bird
            } else if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].toObserveBirds.remove(at: birdIndex)
                sharedWatchlists[index].observedBirds.append(bird)
            } else {
                sharedWatchlists[index].observedBirds.append(bird)
            }
        }
        saveData()
    }
    
    func updateBird(_ bird: Bird, watchlistId: UUID) {
        guard let (type, index) = findWatchlistIndex(id: watchlistId) else { return }
        
        switch type {
        case .custom:
            if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].observedBirds[birdIndex] = bird
            } else if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].toObserveBirds[birdIndex] = bird
            }
        case .shared:
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
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Watchlist title cannot be empty")
            return
        }
        guard startDate <= endDate else {
            print("Error: Start date must be before or equal to end date")
            return
        }
        
        if let index = watchlists.firstIndex(where: { $0.id == id }) {
            watchlists[index].title = title
            watchlists[index].location = location
            watchlists[index].startDate = startDate
            watchlists[index].endDate = endDate
            saveData()
        }
    }
    
    func updateSharedWatchlist(id: UUID, title: String, location: String, dateRange: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Shared watchlist title cannot be empty")
            return
        }
        
        if let index = sharedWatchlists.firstIndex(where: { $0.id == id }) {
            sharedWatchlists[index].title = title
            sharedWatchlists[index].location = location
            sharedWatchlists[index].dateRange = dateRange
            saveData()
        }
    }
    
    func updateSharedWatchlistUserImages(id: UUID, userImages: [String]) {
        if let index = sharedWatchlists.firstIndex(where: { $0.id == id }) {
            sharedWatchlists[index].userImages = userImages
            saveData()
        }
    }
    
    func addWatchlist(_ watchlist: Watchlist) {
        guard !watchlist.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Watchlist title cannot be empty")
            return
        }
        watchlists.append(watchlist)
        saveData()
    }
    
    func addSharedWatchlist(_ watchlist: SharedWatchlist) {
        guard !watchlist.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Shared watchlist title cannot be empty")
            return
        }
        sharedWatchlists.append(watchlist)
        saveData()
    }
    
    // MARK: - Extension for Specific Bird Addition
    
    func addRoseRingedParakeetToMyWatchlist() {
        let defaultWatchlistID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        
        if let id = defaultWatchlistID, let index = watchlists.firstIndex(where: { $0.id == id }) {
            let roseRingedParakeet = Bird(
                id: UUID(),
                name: "Rose-ringed Parakeet",
                scientificName: "Psittacula krameri",
                images: ["rose_ringed_parakeet"],
                rarity: [.common],
                location: ["Pune, India"],
                date: [Date()],
                observedBy: nil,
                notes: "Added by user request."
            )
            watchlists[index].toObserveBirds.append(roseRingedParakeet)
            saveData()
            print("Rose-ringed Parakeet added to default watchlist successfully.")
        } else {
            print("Error: Default watchlist not found. Use addWatchlist() to create one first.")
        }
    }
}
