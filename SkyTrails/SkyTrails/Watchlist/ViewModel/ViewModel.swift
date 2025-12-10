	//
	//  ViewModel.swift
	//  SkyTrails
	//

import Foundation

class WatchlistViewModel {
	
	var watchlists: [Watchlist] = []
    var sharedWatchlists: [SharedWatchlist] = []
	
	init() {
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
                stats: (18, 7),
                userImages: ["person.crop.circle.fill", "person.crop.circle", "person.circle.fill", "person.crop.circle.fill", "person.crop.circle"],
                observedBirds: Array(firstHalf.prefix(max(1, firstHalf.count / 2))), // At least one bird observed
                toObserveBirds: Array(firstHalf.suffix(max(1, firstHalf.count - firstHalf.count / 2))) // At least one bird to observe
            ),
            SharedWatchlist(
                title: "Feather Trail",
                location: "Singhad Valley",
                dateRange: "12th Oct - 15th Nov",
                mainImageName: "HimalayanMonal",
                stats: (10, 2),
                userImages: ["person.circle.fill", "person.crop.circle", "person.crop.circle.fill", "person.crop.circle"],
                observedBirds: Array(secondHalf.prefix(max(1, secondHalf.count / 2))), // At least one bird observed
                toObserveBirds: Array(secondHalf.suffix(max(1, secondHalf.count - secondHalf.count / 2))) // At least one bird to observe
            )
        ]
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
            return
        }
        
        if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
            if asObserved {
                sharedWatchlists[index].observedBirds.append(contentsOf: birds)
            } else {
                sharedWatchlists[index].toObserveBirds.append(contentsOf: birds)
            }
        }
    }
    
    func deleteBird(_ bird: Bird, from watchlistId: UUID) {
        if let index = watchlists.firstIndex(where: { $0.id == watchlistId }) {
            if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].observedBirds.remove(at: birdIndex)
            }
            if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].toObserveBirds.remove(at: birdIndex)
            }
            return
        }
        
        if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
            if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].observedBirds.remove(at: birdIndex)
            }
            if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].toObserveBirds.remove(at: birdIndex)
            }
        }
    }
    
    func saveObservation(bird: Bird, watchlistId: UUID) {
        // 1. Check My Watchlists
        if let index = watchlists.firstIndex(where: { $0.id == watchlistId }) {
            // Case A: Update existing Observed
            if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].observedBirds[birdIndex] = bird
                return
            }
            
            // Case B: Move from To Observe -> Observed
            if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                watchlists[index].toObserveBirds.remove(at: birdIndex)
                watchlists[index].observedBirds.append(bird)
                return
            }
            
            // Case C: New Observation
            watchlists[index].observedBirds.append(bird)
            return
        }
        
        // 2. Check Shared Watchlists
        if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
            // Case A: Update existing Observed
            if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].observedBirds[birdIndex] = bird
                return
            }
            
            // Case B: Move from To Observe -> Observed
            if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                sharedWatchlists[index].toObserveBirds.remove(at: birdIndex)
                sharedWatchlists[index].observedBirds.append(bird)
                return
            }
            
            // Case C: New Observation
            sharedWatchlists[index].observedBirds.append(bird)
        }
    }
    
    func updateBird(_ bird: Bird, watchlistId: UUID) {
         // 1. Check My Watchlists
         if let index = watchlists.firstIndex(where: { $0.id == watchlistId }) {
             if let birdIndex = watchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                 watchlists[index].observedBirds[birdIndex] = bird
                 return
             }
             if let birdIndex = watchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                 watchlists[index].toObserveBirds[birdIndex] = bird
                 return
             }
         }
         
         // 2. Check Shared Watchlists
         if let index = sharedWatchlists.firstIndex(where: { $0.id == watchlistId }) {
             if let birdIndex = sharedWatchlists[index].observedBirds.firstIndex(where: { $0.id == bird.id }) {
                 sharedWatchlists[index].observedBirds[birdIndex] = bird
                 return
             }
             if let birdIndex = sharedWatchlists[index].toObserveBirds.firstIndex(where: { $0.id == bird.id }) {
                 sharedWatchlists[index].toObserveBirds[birdIndex] = bird
                 return
             }
         }
    }
}
