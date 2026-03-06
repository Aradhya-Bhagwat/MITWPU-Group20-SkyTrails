
import Foundation

enum Rarity: String, Codable {
    case rare
    case common
}

struct BirdLegacy: Codable {
    var id: UUID = UUID()
    
    var name: String
    let scientificName: String
    
    var images: [String]
    
    var rarity : [Rarity]
    
    var location: [String]
    var date : [Date]
    
    var observedBy: [String]?
    
    var notes: String?
}
