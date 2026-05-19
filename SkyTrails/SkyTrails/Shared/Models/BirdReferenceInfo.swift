import Foundation
import SwiftData

@Model
final class BirdReferenceInfo {
    @Attribute(.unique)
    var speciesCode: String
    var commonName: String
    var scientificName: String
    var wikiTitle: String?
    var sourceURL: String?
    var fieldMarks: String?
    var size: String?
    var weight: String?
    var habitat: String?
    var behavior: String?
    var similarSpecies: String?
    var family: String?
    var orderName: String?
    var genus: String?
    var notes: String?

    init(
        speciesCode: String,
        commonName: String,
        scientificName: String,
        wikiTitle: String? = nil,
        sourceURL: String? = nil,
        fieldMarks: String? = nil,
        size: String? = nil,
        weight: String? = nil,
        habitat: String? = nil,
        behavior: String? = nil,
        similarSpecies: String? = nil,
        family: String? = nil,
        orderName: String? = nil,
        genus: String? = nil,
        notes: String? = nil
    ) {
        self.speciesCode = speciesCode
        self.commonName = commonName
        self.scientificName = scientificName
        self.wikiTitle = wikiTitle
        self.sourceURL = sourceURL
        self.fieldMarks = fieldMarks
        self.size = size
        self.weight = weight
        self.habitat = habitat
        self.behavior = behavior
        self.similarSpecies = similarSpecies
        self.family = family
        self.orderName = orderName
        self.genus = genus
        self.notes = notes
    }
}
