	//
	//  IdentificationModels.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 25/11/25.
	//

import Foundation

	// MARK: - Database Structure (JSON)

struct BirdDatabase: Codable {
	var birds: [ReferenceBird] // Changed to var so we can append user birds
	let reference_data: ReferenceData
	
	enum CodingKeys: String, CodingKey {
		case birds
		case reference_data
	}
}

struct ReferenceData: Codable {
	let shapes: [BirdShape]
}

struct BirdShape: Codable {
	let id: String
	let name: String
	let icon: String
	// Computed property for UI convenience
	var imageView: String { return icon }
}

// MARK: - Main Bird Model (Source of Truth)

struct ReferenceBird: Codable, Identifiable {
	let id: String
	let commonName: String
	let scientificName: String?
	let imageName: String
	let validLocations: [String]
	let attributes: BirdAttributes
	let fieldMarks: [FieldMarkData]
	var isUserCreated: Bool? = false
	
		// Maps JSON snake_case to Swift camelCase
	enum CodingKeys: String, CodingKey {
		case id
		case commonName = "common_name"
		case scientificName = "scientific_name"
		case imageName = "image_name"
		case validLocations = "valid_locations"
		case attributes
		case fieldMarks = "field_marks"
		case isUserCreated
	}
}

struct BirdAttributes: Codable {
	let shapeId: String
	let sizeCategory: Int
	let rarity: String
	
	enum CodingKeys: String, CodingKey {
		case shapeId = "shape_id"
		case sizeCategory = "size_category"
		case rarity
	}
}

struct FieldMarkData: Codable {
	let area: String
	let variant: String
	let colors: [String]
}

// MARK: - UI & History Support Models

struct History: Codable {
	var imageView: String
	var specieName: String
	var date: String
}

struct FieldMarkType: Codable {
	var symbols: String
	var fieldMarkName: String
	var isSelected: Bool? = false
}

struct ChooseFieldMark: Codable {
	var imageView: String
	var name: String
	var isSelected: Bool? = false
}

// MARK: - Identification Result Model (Output)
// This is the struct used to display results after filtering
struct IdentificationBird: Codable, Identifiable {
	let id: String
	let name: String
	let scientificName: String
	let confidence: Double // 0.0 to 1.0 (Match Percentage)
	let description: String // "Matched: Size, Shape, Crown"
	let imageName: String
	
		// Helper to Convert to Saved Logbook Bird
	func toSavedBird(location: String?) -> Bird {
		return Bird(
			id: UUID(),
			name: self.name,
			scientificName: self.scientificName,
			images: [self.imageName],
			rarity: [.common],
			location: location != nil ? [location!] : [],
			date: [Date()],
			observedBy: nil,
			notes: "Identified via Filter: \(self.description)"
		)
	}
}

// MARK: - Data Manager (Persistence & Loading)

class IdentificationModels {
	
	var masterDatabase: BirdDatabase?
	var histories: [History] = []
	
		// UI Helpers
	var fieldMarkOptions: [FieldMarkType] = []
	var birdShapes: [BirdShape] = []
	var chooseFieldMarks: [ChooseFieldMark] = []
	
	init() {
		do {
				// 1. Load Static JSON Database
			var db = try loadDatabase()
			
				// 2. Load User Created Birds (Persistence)
			let userBirds = loadUserBirds()
			db.birds.append(contentsOf: userBirds)
			
			self.masterDatabase = db
			print("✅ BIRD DATABASE LOADED SUCCESSFULLY")
			
				// 3. Load History
			self.histories = loadHistory()
			
				// 4. Populate UI Models
			self.populateUIModels()
			
		} catch {
			print("❌ IDENTIFICATION DATABASE LOAD FAILED:", error)
		}
	}
	
		// MARK: - Loading Logic
	
	private func loadDatabase() throws -> BirdDatabase {
		guard let url = Bundle.main.url(forResource: "bird_database", withExtension: "json") else {
			throw NSError(domain: "IdentificationModels", code: 404, userInfo: [NSLocalizedDescriptionKey: "bird_database.json not found"])
		}
		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode(BirdDatabase.self, from: data)
	}
	
	private func populateUIModels() {
		guard let db = masterDatabase else { return }
		
			// 1. Shapes
		self.birdShapes = db.reference_data.shapes
		
			// 2. Field Mark Menu Options
		self.fieldMarkOptions = [
			FieldMarkType(symbols: "icn_location_date_pin", fieldMarkName: "Location & Date"),
			FieldMarkType(symbols: "icn_size", fieldMarkName: "Size"),
			FieldMarkType(symbols: "icn_shape_bird_question", fieldMarkName: "Shape"),
			FieldMarkType(symbols: "icn_field_marks", fieldMarkName: "Field Marks")
		]
		
			// 3. Flatten Field Marks for UI Selection
			// Get unique areas from the first few birds or define statically if preferred
			// For now, we extract unique areas from the database to populate the list
		let allMarks = db.birds.flatMap { $0.fieldMarks }
		let uniqueAreas = Array(Set(allMarks.map { $0.area })).sorted()
		
		self.chooseFieldMarks = uniqueAreas.map { area in
			let imageName = "bird_\(area.lowercased())"
			return ChooseFieldMark(imageView: imageName, name: area)
		}
	}
	
		// MARK: - Persistence
	
	private func getDocumentsDirectory() -> URL {
		return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}
	
	private func loadUserBirds() -> [ReferenceBird] {
		let url = getDocumentsDirectory().appendingPathComponent("user_birds.json")
		guard let data = try? Data(contentsOf: url) else { return [] }
		return (try? JSONDecoder().decode([ReferenceBird].self, from: data)) ?? []
	}
	
	func saveUserBirds() {
		guard let db = masterDatabase else { return }
		let userBirds = db.birds.filter { $0.isUserCreated == true }
		let url = getDocumentsDirectory().appendingPathComponent("user_birds.json")
		
		do {
			let data = try JSONEncoder().encode(userBirds)
			try data.write(to: url)
		} catch {
			print("❌ Failed to save user birds: \(error)")
		}
	}
	
	private func loadHistory() -> [History] {
		let url = getDocumentsDirectory().appendingPathComponent("history.json")
		guard let data = try? Data(contentsOf: url) else { return [] }
		return (try? JSONDecoder().decode([History].self, from: data)) ?? []
	}
	
	func saveHistory() {
		let url = getDocumentsDirectory().appendingPathComponent("history.json")
		do {
			let data = try JSONEncoder().encode(histories)
			try data.write(to: url)
		} catch {
			print("❌ Failed to save history: \(error)")
		}
	}
	
		// MARK: - CRUD
	
	func addBird(_ bird: ReferenceBird) {
		var newBird = bird
		newBird.isUserCreated = true
		masterDatabase?.birds.append(newBird)
		saveUserBirds()
	}
	
	func deleteBird(id: String) {
		guard let index = masterDatabase?.birds.firstIndex(where: { $0.id == id }) else { return }
		let bird = masterDatabase?.birds[index]
		if bird?.isUserCreated == true {
			masterDatabase?.birds.remove(at: index)
			saveUserBirds()
		}
	}
}
