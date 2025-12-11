//
//  IdentificationModels.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import Foundation

// MARK: - Master Database Structure

struct MasterDatabase: Codable {
    let referenceData: ReferenceData
    var birds: [MasterBird]
    
    enum CodingKeys: String, CodingKey {
        case referenceData = "reference_data"
        case birds
    }
}

struct ReferenceData: Codable {
    let shapes: [ShapeReference]
    let locations: [String]
    let colors: [String]
    let fieldMarks: [FieldMarkReference]
    
    enum CodingKeys: String, CodingKey {
        case shapes, locations, colors
        case fieldMarks = "field_marks"
    }
}

struct ShapeReference: Codable {
    let id: String
    let name: String
    let icon: String
}

struct FieldMarkReference: Codable {
    let area: String
    let variants: [String]
}

// MARK: - Master Bird Model

struct MasterBird: Codable {
    let id: String
    let commonName: String
    let scientificName: String
    let imageName: String
    let validLocations: [String]
    let attributes: BirdAttributes
    let fieldMarks: [FieldMarkData]
    var isUserCreated: Bool? = false
    
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
    
    func toWatchlistBird() -> Bird {
        let rarityEnum = Rarity(rawValue: attributes.rarity) ?? .common
        
        return Bird(
            id: UUID(),
            name: commonName,
            scientificName: scientificName,
            images: [imageName],
            rarity: [rarityEnum],
            location: validLocations,
            date: [Date()],
            observedBy: nil,
            notes: nil
        )
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

// MARK: - Legacy / UI Support Models

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

struct BirdShape: Codable {
    var imageView: String
    var name: String
    var sizeCategory: [Int]? = nil
    var id: String?
}

struct ChooseFieldMark: Codable {
    var imageView: String
    var name: String
    var isSelected: Bool? = false
}

struct BirdResult: Codable {
    let name: String
    let percentage: Int
    let imageView: String
    var masterBirdId: String? = nil 
}

// MARK: - Data Loader & Persistence

class IdentificationModels {
    var masterDatabase: MasterDatabase?
    var histories: [History] = []
    
    // Legacy properties
    var fieldMarkOptions: [FieldMarkType] = []
    var birdShapes: [BirdShape] = []
    var chooseFieldMarks: [ChooseFieldMark] = []
    var birdResults: [BirdResult] = []

    init() {
        do {
            // 1. Load Static Database
            var db = try loadDatabase()
            
            // 2. Load User Birds (Persistence)
            let userBirds = loadUserBirds()
            db.birds.append(contentsOf: userBirds)
            
            self.masterDatabase = db
            print("✅ BIRD DATABASE LOADED SUCCESSFULLY")
            
            // 3. Load History (Persistence)
            self.histories = loadHistory()
            
            // 4. Populate UI
            self.populateUIModels()
            
        } catch {
            print("❌ IDENTIFICATION DATABASE LOAD FAILED:", error)
        }
    }
    
    // MARK: - Loading Logic
    
    private func loadDatabase() throws -> MasterDatabase {
        guard let url = Bundle.main.url(forResource: "bird_database", withExtension: "json") else {
            throw NSError(domain: "IdentificationModels",
                          code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "bird_database.json not found"])
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(MasterDatabase.self, from: data)
    }
    
    private func populateUIModels() {
        guard let db = masterDatabase else { return }
        
        // 1. Shapes
        self.birdShapes = db.referenceData.shapes.map { shape in
            BirdShape(imageView: shape.icon, name: shape.name, sizeCategory: nil, id: shape.id)
        }
        
        // 2. Field Mark Options (Categories for the main menu)
        self.fieldMarkOptions = [
            FieldMarkType(symbols: "icn_location_date_pin", fieldMarkName: "Location & Date"),
            FieldMarkType(symbols: "icn_size", fieldMarkName: "Size"),
            FieldMarkType(symbols: "icn_shape_bird_question", fieldMarkName: "Shape"),
            FieldMarkType(symbols: "icn_field_marks", fieldMarkName: "Field Marks")
        ]
        
        // 3. Detailed Field Marks (for the selection screen)
        // Map one entry per Area (e.g., "Back", "Beak"), not per variant.
        self.chooseFieldMarks = db.referenceData.fieldMarks.map { fm in
            // Construct image name: "bird_" + area name lowercased (e.g., "bird_back", "bird_wings")
            let imageName = "bird_\(fm.area.lowercased())"
            return ChooseFieldMark(imageView: imageName, name: fm.area)
        }
    }
    
    // MARK: - Persistence Methods
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func loadUserBirds() -> [MasterBird] {
        let url = getDocumentsDirectory().appendingPathComponent("user_birds.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([MasterBird].self, from: data)) ?? []
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
    
    // MARK: - CRUD Operations
    
    func addBird(_ bird: MasterBird) {
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
        } else {
            print("⚠️ Cannot delete default database birds.")
        }
    }
}

