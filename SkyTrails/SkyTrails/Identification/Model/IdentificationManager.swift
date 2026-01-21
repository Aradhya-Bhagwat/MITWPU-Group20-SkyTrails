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
    var selectedSizeRange: [Int] = []

    
    
    var data = IdentificationData()
    var selectedSizeCategory: Int?
    var selectedShapeId: String?
    var selectedLocation: String?
    var selectedFieldMarks: [FieldMarkData] = []
    
    
    var birdResults: [Bird2] = []
    
    
    var onResultsUpdated: (() -> Void)?
    
    init() {
        loadAllData()
    }
  

    private func loadAllData() {
        do {
            // Initialize UI options
            self.fieldMarkOptions = [
                FieldMarkType(symbols: "home_icn_location_date_pin", fieldMarkName: .locationDate, isSelected: false),
                FieldMarkType(symbols: "id_icn_size", fieldMarkName: .size, isSelected: false),
                FieldMarkType(symbols: "id_icn_shape_bird_question", fieldMarkName: .shape, isSelected: false),
                FieldMarkType(symbols: "id_icn_field_marks", fieldMarkName: .fieldMarks, isSelected: false)
            ]
            var db = try loadDatabase()
            let userBirds = loadUserBirds()
            db.birds.append(contentsOf: userBirds)
            
            self.masterDatabase = db
            self.birdShapes = db.referenceData.shapes
            self.histories = loadHistory()
            self.chooseFieldMarks = db.referenceData.fieldMarks.map { mark in
                ChooseFieldMark(imageView: "id_bird_\(mark.area.lowercased())", name: mark.area)
            }.sorted { $0.name < $1.name }
            
            print("Model Loaded Successfully")
            
        } catch {
            print("Model Load Failed:", error)
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
        if let size = size {
            self.selectedSizeRange = sizeRange(for: size)
        }

        if let location = location { self.selectedLocation = location }
        if let fieldMarks = fieldMarks, !fieldMarks.isEmpty {
            self.selectedFieldMarks = fieldMarks
        }

        let currentShape = self.selectedShapeId
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

            if let birdSize = bird.sizeCategory {

                if selectedSizeRange.contains(birdSize) {

                    if birdSize == selectedSizeCategory {
                        score += 20
                        breakdownParts.append("Size Match (+20)")
                    } else {
                        score += 10
                        breakdownParts.append("Size Approx (+10)")
                    }

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
                    var bird = item.bird
                    bird.confidence = item.score
                    bird.scoreBreakdown = item.breakdown
                    return bird
                }

        // 5. Notify UI ONCE
        DispatchQueue.main.async {
            self.onResultsUpdated?()
        }

        }
    func availableShapesForSelectedSize() -> [BirdShape] {
        guard !selectedSizeRange.isEmpty,
              let birds = masterDatabase?.birds else {
            return birdShapes
        }

        let validShapeIds: Set<String> = Set(
            birds.compactMap { bird in
                guard let birdSize = bird.sizeCategory,
                      selectedSizeRange.contains(birdSize) else { return nil }
                return bird.shapeId
            }
        )

        return birdShapes.filter { validShapeIds.contains($0.id) }
    }

        var referenceFieldMarks: [ReferenceFieldMark] {
            return masterDatabase?.referenceData.fieldMarks ?? []
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
                    print("CRITICAL: Failed to decode user_birds.json:", error)
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
                print("Failed to save user_birds.json:", error)
            }
        }
        
        func loadHistory() -> [History] {
            let url = getDocumentsDirectory().appendingPathComponent("history.json")
                let decoder = JSONDecoder()
            // 1. Try Documents
            if let data = try? Data(contentsOf: url) {
                do {
                    return try decoder.decode([History].self, from: data)
                } catch {
                    print("CRITICAL: Failed to decode history.json from Documents:", error)
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
                    print("CRITICAL: Failed to decode history.json from Bundle:", error)
                }
            }
            
            return []
        }
        
        
    func sizeRange(for index: Int) -> [Int] {
        let minIndex = max(0, index - 1)
        let maxIndex = min(4, index + 1)
        return Array(minIndex...maxIndex)
    }

        func saveHistory() {
            let url = getDocumentsDirectory().appendingPathComponent("history.json")
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(histories)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save history.json:", error)
            }
        }
        
        
    }

