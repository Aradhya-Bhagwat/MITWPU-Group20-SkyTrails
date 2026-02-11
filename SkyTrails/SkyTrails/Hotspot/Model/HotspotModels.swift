//
//  HotspotModels.swift
//  SkyTrails
//

import Foundation
import SwiftData

@Model
final class Hotspot {
    @Attribute(.unique)
    var id: UUID
    
    var name: String
    var locality: String?
    var lat: Double
    var lon: Double
    var imageName: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \HotspotSpeciesPresence.hotspot)
    var speciesList: [HotspotSpeciesPresence]?
    
    init(id: UUID = UUID(), name: String, locality: String? = nil, lat: Double, lon: Double, imageName: String? = nil) {
        self.id = id
        self.name = name
        self.locality = locality
        self.lat = lat
        self.lon = lon
        self.imageName = imageName
    }
}

@Model
final class HotspotSpeciesPresence {
    @Attribute(.unique)
    var id: UUID
    
    var hotspot: Hotspot?
    var bird: Bird?
    
    // Seasonality data
    var validWeeks: [Int]? // Week numbers when species is present
    var probability: Int? // Likelihood of sighting (0-100)
    
    init(id: UUID = UUID(), hotspot: Hotspot? = nil, bird: Bird? = nil, validWeeks: [Int]? = nil, probability: Int? = nil) {
        self.id = id
        self.hotspot = hotspot
        self.bird = bird
        self.validWeeks = validWeeks
        self.probability = probability
    }
}
