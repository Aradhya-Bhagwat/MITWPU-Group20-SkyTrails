//
//  Bird.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation

enum Rarity: String, Codable {
    case rare
    case common
}

struct Bird: Codable {
    var id: UUID = UUID()
    
    var name: String
    let scientificName: String
    
    var images: [String]
    
    var rarity : [Rarity]
    
    var location: [String]
    var date : [Date]
    
    var observedBy: [String]? // List of user image names/SF symbols who observed this bird
    
    var notes: String?
}
