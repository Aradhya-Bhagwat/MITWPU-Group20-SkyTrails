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
        self.sharedWatchlists = [
            SharedWatchlist(
                title: "Canopy Wanderers",
                location: "Vetal tekdi",
                dateRange: "8th Oct - 7th Nov",
                mainImageName: "AsianFairyBluebird",
                stats: (18, 7),
                userImages: ["person.crop.circle.fill", "person.crop.circle", "person.circle.fill", "person.crop.circle.fill", "person.crop.circle"]
            ),
            SharedWatchlist(
                title: "Feather Trail",
                location: "Singhad Valley",
                dateRange: "12th Oct - 15th Nov",
                mainImageName: "HimalayanMonal",
                stats: (10, 2),
                userImages: ["person.circle.fill", "person.crop.circle", "person.crop.circle.fill", "person.crop.circle"]
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
}
