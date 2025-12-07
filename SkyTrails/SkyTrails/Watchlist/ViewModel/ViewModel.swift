	//
	//  ViewModel.swift
	//  SkyTrails
	//

import Foundation

class WatchlistViewModel {
	
	    var watchlists: [Watchlist] = []
	    var sharedWatchlists: [SharedWatchlist] = []
	    
	    // Master list of birds for search
	    private var allBirds: [Bird] = []
	    
	    init() {
	        self.watchlists = createMockWatchlists()
	        
	        // Populate master list from mock watchlists
	        // In a real app, this would fetch from a database or API
	        let observed = self.watchlists.flatMap { $0.observedBirds }
	        let toObserve = self.watchlists.flatMap { $0.toObserveBirds }
	        // De-duplicate birds by ID
	        let combined = observed + toObserve
	        var uniqueBirds = [UUID: Bird]()
	        for bird in combined {
	            uniqueBirds[bird.id] = bird
	        }
	        self.allBirds = Array(uniqueBirds.values)
	        
	        // Helper to get some random birds from mock watchlists        // Ensure we have enough birds for distinct lists
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
			    
			    // MARK: - Actions
			    
			    func searchBirds(query: String) -> [Bird] {
			        if query.isEmpty {
			            return allBirds
			        }
			        return allBirds.filter { bird in
			            bird.name.localizedCaseInsensitiveContains(query) ||
			            bird.scientificName.localizedCaseInsensitiveContains(query)
			        }
			    }
			    
			    func createWatchlist(name: String, image: UIImage?, start: Date, end: Date, location: String) {
			        // Note: The Watchlist model currently does not support an image field.
			        // We are accepting the image parameter as requested but it won't be stored in the model.
			        let newWatchlist = Watchlist(
			            title: name,
			            location: location,
			            startDate: start,
			            endDate: end,
			            observedBirds: [],
			            toObserveBirds: []
			        )
			        self.watchlists.append(newWatchlist)
			    }
			}
			
