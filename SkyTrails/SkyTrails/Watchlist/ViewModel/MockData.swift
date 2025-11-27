//
//  MockData.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import Foundation

func createMockWatchlists() -> [Watchlist] {
        // 1. Create Birds using your specific Asset Names
        // Note: I am assuming the 'images' parameter takes an array of Strings (asset names).
    
    let bird1 = Bird(
        name: "Himalayan Monal",
        scientificName: "Lophophorus impejanus",
        images: ["HimalayanMonal"], // Matches your asset name
        rarity: [.rare],
        location: [],
        date: [],
        isObserved: true
    )
    
    let bird2 = Bird(
        name: "Asian Koel",
        scientificName: "Eudynamys scolopaceus",
        images: ["AsianKoel"], // Matches your asset name
        rarity: [.common],
        location: [],
        date: [],
        isObserved: false
    )
    
    let bird3 = Bird(
        name: "Indian Peafowl",
        scientificName: "Pavo cristatus",
        images: ["IndianPeafowl"], // Matches your asset name
        rarity: [.common],
        location: [],
        date: [],
        isObserved: true
    )
    
    let bird4 = Bird(
        name: "Great Hornbill",
        scientificName: "Buceros bicornis",
        images: ["GreatHornbill"],
        rarity: [.rare],
        location: [],
        date: [],
        isObserved: false
    )
    
    let bird5 = Bird(
        name: "Oriental Magpie-Robin",
        scientificName: "Copsychus saularis",
        images: ["OrientalMagpieRobin"],
        rarity: [.common],
        location: [],
        date: [],
        isObserved: true
    )
    
    let bird6 = Bird(
        name: "Greater Flameback",
        scientificName: "Chrysocolaptes lucidus",
        images: ["GreaterFlameback"],
        rarity: [.rare],
        location: [],
        date: [],
        isObserved: false
    )
    
        // 2. Create Watchlists
        // "My Watchlist" (The main card)
    let watchlist1 = Watchlist(
        title: "My Watchlist",
        location: "Home",
        startDate: Date(),
        endDate: Date(),
        birds: [bird1, bird2] // Monal is the "Cover" bird here
    )
    
    let watchlist2 = Watchlist(
        title: "Jungle Safari",
        location: "National Park",
        startDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
        endDate: Date().addingTimeInterval(-86400 * 20), // 20 days ago
        birds: [bird3, bird5]
    )
    
    let watchlist3 = Watchlist(
        title: "Himalayan Expedition",
        location: "Himalayas",
        startDate: Date().addingTimeInterval(-86400 * 60),
        endDate: Date().addingTimeInterval(-86400 * 45),
        birds: [bird1, bird4]
    )
    
    let watchlist4 = Watchlist(
        title: "Backyard Birds",
        location: "My Garden",
        startDate: Date().addingTimeInterval(-86400 * 10),
        endDate: Date(),
        birds: [bird2, bird5]
    )
    
    let watchlist5 = Watchlist(
        title: "Tropical Forest",
        location: "Amazon",
        startDate: Date().addingTimeInterval(-86400 * 90),
        endDate: Date().addingTimeInterval(-86400 * 70),
        birds: [bird3, bird6]
    )
    
    let watchlist6 = Watchlist(
        title: "Desert Birds",
        location: "Thar Desert",
        startDate: Date().addingTimeInterval(-86400 * 5),
        endDate: Date().addingTimeInterval(-86400 * 1),
        birds: [bird2, bird3]
    )
    
    return [watchlist1, watchlist2, watchlist3, watchlist4, watchlist5, watchlist6]
}
