//
//  IdentificationManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/01/26.
//

import Foundation
import CoreLocation
class IdentificationManager {
    var masterDatabase: BirdDatabase?
    
    var histories: [History] = []
    var fieldMarkOptions: [FieldMarkType] = []
    var birdShapes: [BirdShape] = []
    var chooseFieldMarks: [ChooseFieldMark] = []
    
    
    var data = IdentificationData()
    var selectedSizeCategory: Int?
    var selectedShapeId: String?
    var selectedLocation: String?
    var selectedFieldMarks: [FieldMarkData] = []
    
    
    var birdResults: [IdentificationBird] = []
    
    
    var onResultsUpdated: (() -> Void)?
    
    init() {
        loadAllData()
    }
  

    private func loadAllData() {
        do {
            self.fieldMarkOptions = [
                FieldMarkType(
                    symbols: "icn_location_date_pin",
                    fieldMarkName: .locationDate,
                    isSelected: false
                ),
                FieldMarkType(
                    symbols: "icn_size",
                    fieldMarkName: .size,
                    isSelected: false
                ),
                FieldMarkType(
                    symbols: "icn_shape_bird_question",
                    fieldMarkName: .shape,
                    isSelected: false
                ),
                FieldMarkType(
                    symbols: "icn_field_marks",
                    fieldMarkName: .fieldMarks,
                    isSelected: false
                )
            ]
            let data = try Data(contentsOf: Bundle.main.url(forResource: "bird_database", withExtension: "json")!)
            let decoder = JSONDecoder()

            // ✅ Decode reference_data separately
            let container = try decoder.decode(
                [String: ReferenceData].self,
                from: data
            )

            if let ref = container["reference_data"] {
                self.birdShapes = ref.shapes
                print("✅ Shapes loaded:", birdShapes.count)
            }


            // 1. Database
            var db = try loadDatabase()
            let userBirds = loadUserBirds()
            db.birds.append(contentsOf: userBirds)
            self.masterDatabase = db
            self.birdShapes = db.reference_data.shapes
            // 2. History
            self.histories = loadHistory()
            
            // 3. UI Helpers
         
          

            
            let allMarks = db.birds.compactMap { $0.fieldMarks }.flatMap { $0 }
            
            let uniqueAreas = Array(Set(allMarks.map { $0.area })).sorted()
            self.chooseFieldMarks = uniqueAreas.map { area in
                ChooseFieldMark(imageView: "bird_\(area.lowercased())", name: area)
            }
            
            print("✅ MVC Model Loaded Successfully")
            
        } catch {
            print("❌ Model Load Failed:", error)
        }
    }
    
    private func loadDatabase() throws -> BirdDatabase {
        guard let url = Bundle.main.url(forResource: "bird_database", withExtension: "json") else {
            throw NSError(domain: "Model", code: 404, userInfo: ["msg": "json not found"])
        }
        return try JSONDecoder().decode(BirdDatabase.self, from: try Data(contentsOf: url))
    }
    
    func filterBirds(shape: String?, size: Int?, location: String?, fieldMarks: [FieldMarkData]?) {
        guard let allBirds = masterDatabase?.birds else { return }

        if let shape = shape { self.selectedShapeId = shape }
        if let size = size { self.selectedSizeCategory = size }
        if let location = location { self.selectedLocation = location }
        if let fieldMarks = fieldMarks, !fieldMarks.isEmpty {
            self.selectedFieldMarks = fieldMarks
        }

        let currentShape = self.selectedShapeId
        let currentSize = self.selectedSizeCategory
        let currentLocation = self.selectedLocation
        let currentFieldMarks = self.selectedFieldMarks

        // Date logic
        var searchMonth: Int?
        if let dateString = data.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM yyyy"
            if let date = formatter.date(from: dateString) {
                searchMonth = Calendar.current.component(.month, from: date)
            }
        }

        var scoredBirds: [(bird: Bird2, score: Double, breakdown: String)] = []

        // 3. Scoring loop
        for bird in allBirds {

            var score = 0.0
            var breakdownParts: [String] = []

            // A. Location
            if let loc = currentLocation,
               let locations = bird.validLocations,
               !locations.contains(loc) {
                score -= 5
                breakdownParts.append("Wrong Location (-30)")
            }

            // B. Seasonality
            if let month = searchMonth,
               let validMonths = bird.validMonths,
               !validMonths.contains(month) {
                score -= 50
                breakdownParts.append("Wrong Season (-50)")
            }

            // C. Shape
            if let userShape = currentShape,
               bird.shapeId == userShape {
                score += 30
                breakdownParts.append("Shape Match (+30)")
            }

            // D. Size
            if let userSize = currentSize,
               let birdSize = bird.sizeCategory {

                let diff = abs(birdSize - userSize)
                if diff == 0 {
                    score += 20
                    breakdownParts.append("Size Match (+20)")
                } else if diff == 1 {
                    score += 10
                    breakdownParts.append("Size Approx (+10)")
                } else {
                    score -= 20
                    breakdownParts.append("Size Mismatch (-20)")
                }
            }

            // E. Field Marks
            if !currentFieldMarks.isEmpty {
                let pointsPerMark = 50.0 / Double(currentFieldMarks.count)

                for userMark in currentFieldMarks {
                    if let birdMarks = bird.fieldMarks,
                       let birdMark = birdMarks.first(where: { $0.area == userMark.area }) {

                        if !userMark.variant.isEmpty {
                            if userMark.variant == birdMark.variant {
                                score += pointsPerMark * 0.6
                                breakdownParts.append("\(userMark.area) (+)")
                            } else {
                                score -= pointsPerMark * 0.5
                            }
                        }
                    }
                }
            }

          
            if let rarities = bird.rarity,
               rarities.contains(.common) {
                score += 5
            }

            let finalScore = max(0.0, score)
            let normalized = min(finalScore / 100.0, 1.0)

            scoredBirds.append((bird, normalized, breakdownParts.joined(separator: ", ")))
        }

        // 4. Sort and store (OUTSIDE loop)
        scoredBirds = scoredBirds.filter { $0.score > 0.3 }
        scoredBirds.sort { $0.score > $1.score }

        self.birdResults = scoredBirds.map { item in
            IdentificationBird(
                id: item.bird.id.uuidString,
                name: item.bird.commonName,
                scientificName: item.bird.scientificName,
                confidence: item.score,
                description: item.breakdown,
                imageName: item.bird.staticImageName,
                scoreBreakdown: item.breakdown
            )
        }

        // 5. Notify UI ONCE
        DispatchQueue.main.async {
            self.onResultsUpdated?()
        }

        }
        func availableShapesForSelectedSize() -> [BirdShape] {
            guard let size = selectedSizeCategory,
                  let birds = masterDatabase?.birds else {
                return birdShapes
            }
            
            let validShapeIds: Set<String> = Set(
                birds.compactMap { bird in
                    guard bird.sizeCategory == size else { return nil }
                    return bird.shapeId
                }
            )


            
            return birdShapes.filter { validShapeIds.contains($0.id) }
        }
        
        var referenceFieldMarks: [ReferenceFieldMark] {
            return masterDatabase?.reference_data.fieldMarks ?? []
        }
        
        func getBird(byName name: String) -> Bird2? {
            return masterDatabase?.birds.first(where: { $0.commonName == name })
        }
        
        func addToHistory(_ item: History) {
            histories.append(item)
            saveHistory()
        }
        
        
        private func getDocumentsDirectory() -> URL {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        
        private func loadUserBirds() -> [Bird2] {
            let url = getDocumentsDirectory().appendingPathComponent("user_birds.json")
            let decoder = JSONDecoder()
            
            if let data = try? Data(contentsOf: url) {
                do {
                    return try decoder.decode([Bird2].self, from: data)
                } catch {
                    print("❌ CRITICAL: Failed to decode user_birds.json:", error)
                    return []
                }
            }
            
            // No bundle fallback by design (user birds are user-only)
            return []
        }
        
        func saveUserBirds() {
            guard let db = masterDatabase else { return }
            
            let userBirds = db.birds.filter { $0.isUserCreated == true }
            let url = getDocumentsDirectory().appendingPathComponent("user_birds.json")
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(userBirds)
                try data.write(to: url, options: .atomic)
            } catch {
                print("❌ Failed to save user_birds.json:", error)
            }
        }
        
        private func loadHistory() -> [History] {
            let url = getDocumentsDirectory().appendingPathComponent("history.json")
            let decoder = JSONDecoder()
            
            // 1. Try Documents
            if let data = try? Data(contentsOf: url) {
                do {
                    return try decoder.decode([History].self, from: data)
                } catch {
                    print("❌ CRITICAL: Failed to decode history.json from Documents:", error)
                }
            }
            
            // 2. Fallback to Bundle (first launch)
            if let bundleURL = Bundle.main.url(forResource: "history", withExtension: "json"),
               let data = try? Data(contentsOf: bundleURL) {
                do {
                    let decoded = try decoder.decode([History].self, from: data)
                    self.histories = decoded
                    saveHistory()
                    
                    return decoded
                } catch {
                    print("❌ CRITICAL: Failed to decode history.json from Bundle:", error)
                }
            }
            
            return []
        }
        
        
        
        func saveHistory() {
            let url = getDocumentsDirectory().appendingPathComponent("history.json")
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(histories)
                try data.write(to: url, options: .atomic)
            } catch {
                print("❌ Failed to save history.json:", error)
            }
        }
        
        
    }

