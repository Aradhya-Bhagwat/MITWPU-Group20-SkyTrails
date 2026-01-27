//
//  Bird2.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/01/26.
//

import Foundation
import CoreLocation
import SwiftData

@Model
final class Bird {
    @Attribute(.unique) var id: UUID
    var name: String
    var scientificName: String
    var staticImageName: String
    
    var lat: Double?
    var lon: Double?
    var validLocations: [String]?
    
    var validMonths: [Int]?
    var observationDates: [Date]?
    var IdentificationShape: String?
    
    var shapeId: String?
    var sizeCategory: Int?
    var rarity: [BirdRarity]?
    var fieldMarks: [FieldMarkData]?
    
    var confidence: Double?
    var scoreBreakdown: String?
    
    var userImages: [String]?
    var observedBy: String?
    var notes: String?
    var isUserCreated: Bool = false
    
    var observationStatusRaw: String?
    var watchlist: Watchlist?
    var sharedWatchlist: SharedWatchlist?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var commonName: String { return name }

    enum BirdRarity: String, Codable {
        case common
        case rare
    }
    
    enum ObservationStatus: String, Codable {
        case observed
        case toObserve
    }
    
    var observationStatus: ObservationStatus {
        get {
            guard let raw = observationStatusRaw, let status = ObservationStatus(rawValue: raw) else {
                return .toObserve
            }
            return status
        }
        set {
            observationStatusRaw = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        scientificName: String,
        staticImageName: String,
        lat: Double? = nil,
        lon: Double? = nil,
        validLocations: [String]? = nil,
        validMonths: [Int]? = nil,
        observationDates: [Date]? = nil,
        IdentificationShape: String? = nil,
        shapeId: String? = nil,
        sizeCategory: Int? = nil,
        rarity: [BirdRarity]? = nil,
        fieldMarks: [FieldMarkData]? = nil,
        confidence: Double? = nil,
        scoreBreakdown: String? = nil,
        userImages: [String]? = nil,
        observedBy: String? = nil,
        notes: String? = nil,
        isUserCreated: Bool = false,
        observationStatus: ObservationStatus = .toObserve
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.staticImageName = staticImageName
        self.lat = lat
        self.lon = lon
        self.validLocations = validLocations
        self.validMonths = validMonths
        self.observationDates = observationDates
        self.IdentificationShape = IdentificationShape
        self.shapeId = shapeId
        self.sizeCategory = sizeCategory
        self.rarity = rarity
        self.fieldMarks = fieldMarks
        self.confidence = confidence
        self.scoreBreakdown = scoreBreakdown
        self.userImages = userImages
        self.observedBy = observedBy
        self.notes = notes
        self.isUserCreated = isUserCreated
        self.observationStatusRaw = observationStatus.rawValue
    }
    
    static func fromSpotBird(_ spotBird: SpotBird) -> Bird {
        return Bird(
            id: UUID(),
            name: spotBird.name,
            scientificName: "",
            staticImageName: spotBird.imageName,
            lat: spotBird.lat,
            lon: spotBird.lon
        )
    }
    
    static func fromReferenceBird(_ refBird: ReferenceBird) -> Bird {
        return Bird(
            id: UUID(uuidString: refBird.id) ?? UUID(),
            name: refBird.commonName,
            scientificName: refBird.scientificName ?? "",
            staticImageName: refBird.imageName,
            lat: nil,
            lon: nil,
            validLocations: refBird.validLocations,
            validMonths: refBird.validMonths,
            observationDates: nil,
            shapeId: refBird.attributes.shapeId,
            sizeCategory: refBird.attributes.sizeCategory,
            rarity: BirdRarity(rawValue: refBird.attributes.rarity.lowercased()).map { [$0] },
            fieldMarks: refBird.fieldMarks,
            userImages: nil,
            observedBy: nil,
            notes: nil,
            isUserCreated: refBird.isUserCreated ?? false
        )
    }
}
