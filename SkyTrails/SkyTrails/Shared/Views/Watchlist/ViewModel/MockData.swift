//
//  MockData.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import Foundation
import CoreLocation

func createMockWatchlists() -> [Watchlist] {
        // 1. Create Birds using your specific Asset Names
        // Note: I am assuming the 'images' parameter takes an array of Strings (asset names).
    
    // Helper for random dates
    func randomDate(daysBack: Int) -> Date {
        return Date().addingTimeInterval(-Double(Int.random(in: 0...daysBack)) * 86400)
    }
    
    // Helper for random location strings
    func randomLocation() -> String {
        let locations = ["Pune, India", "Mumbai, India", "Delhi, India", "Kerala, India", "Goa, India", "Himalayas, Nepal", "Vetal Tekdi, Pune", "Singhad Valley, Pune", "Kanha National Park", "Bandhavgarh Tiger Reserve"]
        return locations.randomElement() ?? "Unknown Location"
    }

    // Creating base birds - we will clone/reuse them
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
    
        // 2. Create Watchlists with distinct observed and toObserve lists
    let watchlist1 = Watchlist(title: "My Watchlist", location: "Home", startDate: Date(), endDate: Date(), observedBirds: [bird1, bird3, bird5], toObserveBirds: [bird2, bird7]) // 3 observed, 2 toObserve
    let watchlist2 = Watchlist(title: "Jungle Safari", location: "National Park", startDate: Date().addingTimeInterval(-86400 * 30), endDate: Date().addingTimeInterval(-86400 * 20), observedBirds: [bird4, bird6], toObserveBirds: [bird8]) // 2 observed, 1 toObserve
    let watchlist3 = Watchlist(title: "Himalayan Expedition", location: "Himalayas", startDate: Date().addingTimeInterval(-86400 * 60), endDate: Date().addingTimeInterval(-86400 * 45), observedBirds: [bird1, bird9], toObserveBirds: [bird4, bird10]) // 2 observed, 2 toObserve
    let watchlist4 = Watchlist(title: "Backyard Birds", location: "My Garden", startDate: Date().addingTimeInterval(-86400 * 10), endDate: Date(), observedBirds: [bird2, bird7], toObserveBirds: [bird3, bird8]) // 2 observed, 2 toObserve
    let watchlist5 = Watchlist(title: "Tropical Forest", location: "Amazon", startDate: Date().addingTimeInterval(-86400 * 90), endDate: Date().addingTimeInterval(-86400 * 70), observedBirds: [bird3, bird9], toObserveBirds: [bird6, bird10]) // 2 observed, 2 toObserve
    let watchlist6 = Watchlist(title: "Desert Birds", location: "Thar Desert", startDate: Date().addingTimeInterval(-86400 * 5), endDate: Date().addingTimeInterval(-86400 * 1), observedBirds: [bird8, bird10], toObserveBirds: [bird1, bird2]) // 2 observed, 2 toObserve
    
    return [watchlist1, watchlist2, watchlist3, watchlist4, watchlist5, watchlist6]
}
