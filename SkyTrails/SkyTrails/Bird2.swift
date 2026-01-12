//
//  Bird2.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/01/26.
//

import Foundation
import CoreLocation



struct Bird2: Codable, Identifiable {
	var id: UUID
	let name: String
	let scientificName: String
	let staticImageName: String
	
	
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
	

	var coordinate: CLLocationCoordinate2D? {
		guard let lat = lat, let lon = lon else { return nil }
		return CLLocationCoordinate2D(latitude: lat, longitude: lon)
	}
	
	var commonName: String { return name }

	enum BirdRarity: String, Codable {
		case common
		case rare

	}
	
	
	static func fromSpotBird(_ spotBird: SpotBird) -> Bird2 {
		return Bird2(
			id: UUID(),
			name: spotBird.name,
			scientificName: "",
			staticImageName: spotBird.imageName,
			lat: spotBird.lat,
			lon: spotBird.lon
		
		)
	}
	
		
    static func fromReferenceBird(_ refBird: ReferenceBird) -> Bird2 {
        return Bird2(
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
