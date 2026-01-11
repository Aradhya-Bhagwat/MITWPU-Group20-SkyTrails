
import Foundation


struct BirdDatabase: Codable {
    var birds: [ReferenceBird]
    let reference_data: ReferenceData
    
    enum CodingKeys: String, CodingKey {
        case birds
        case reference_data
    }
}

struct ReferenceData: Codable {
    let shapes: [BirdShape]
    let fieldMarks: [ReferenceFieldMark]
    
    enum CodingKeys: String, CodingKey {
        case shapes
        case fieldMarks = "field_marks"
    }
}

struct ReferenceFieldMark: Codable {
    let area: String
    let variants: [String]
}

struct BirdShape: Codable {
    let id: String
    let name: String
    let icon: String
  
    let neck_variations: [NeckVariation]?
    
    var imageView: String { return icon }
}

struct NeckVariation: Codable {
    let id: String
    let head_offset_y: Int
}
struct ReferenceBird: Codable, Identifiable {
    let id: String
    let commonName: String
    let scientificName: String?
    let imageName: String
    let validLocations: [String]
    let validMonths: [Int]?
    let attributes: BirdAttributes
    let fieldMarks: [FieldMarkData]
    var isUserCreated: Bool? = false
    
    enum CodingKeys: String, CodingKey {
        case id, attributes, isUserCreated
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case imageName = "image_name"
        case validLocations = "valid_locations"
        case validMonths = "valid_months"
        case fieldMarks = "field_marks"
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

struct IdentificationBird: Codable, Identifiable {
    let id: String
    let name: String
    let scientificName: String
    let confidence: Double
    let description: String
    let imageName: String
    let scoreBreakdown: String
    
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

// MARK: - 2. The Smart Model (Merged Logic)

class IdentificationModels {
    
    // --- Data Storage ---
    var masterDatabase: BirdDatabase?
    var histories: [History] = []
    var fieldMarkOptions: [FieldMarkType] = []
    var birdShapes: [BirdShape] = []
    var chooseFieldMarks: [ChooseFieldMark] = []
    
    // --- State Variables (Moved from ViewModel) ---
    var data = IdentificationData() // Holds generic data
    var selectedSizeCategory: Int?
    var selectedShapeId: String?
    var selectedLocation: String?
    var selectedFieldMarks: [FieldMarkData] = []
    
    // --- Output Results ---
    var birdResults: [IdentificationBird] = []
    
    // Notification Closure (Controller listens to this)
    var onResultsUpdated: (() -> Void)?
    
    init() {
        loadAllData()
    }
    
    // MARK: - Initialization & Loading
    
    private func loadAllData() {
        do {
            // 1. Database
            var db = try loadDatabase()
            let userBirds = loadUserBirds()
            db.birds.append(contentsOf: userBirds)
            self.masterDatabase = db
            
            // 2. History
            self.histories = loadHistory()
            
            // 3. UI Helpers
            self.birdShapes = db.reference_data.shapes
            self.fieldMarkOptions = [
                FieldMarkType(symbols: "icn_location_date_pin", fieldMarkName: "Location & Date"),
                FieldMarkType(symbols: "icn_size", fieldMarkName: "Size"),
                FieldMarkType(symbols: "icn_shape_bird_question", fieldMarkName: "Shape"),
                FieldMarkType(symbols: "icn_field_marks", fieldMarkName: "Field Marks")
            ]
            
            let allMarks = db.birds.flatMap { $0.fieldMarks }
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
    
    // MARK: - Business Logic (Moved from ViewModel)
    
    func filterBirds(shape: String?, size: Int?, location: String?, fieldMarks: [FieldMarkData]?) {
        guard let allBirds = masterDatabase?.birds else { return }
        
        // 1. Update Internal State - Only update what's been provided
        if let shape = shape { self.selectedShapeId = shape }
        if let size = size { self.selectedSizeCategory = size }
        if let location = location { self.selectedLocation = location }
        // Only overwrite field marks if a non-empty array is passed.
        // This prevents the GUI selections from being erased by intermediate steps.
        if let fieldMarks = fieldMarks, !fieldMarks.isEmpty {
            self.selectedFieldMarks = fieldMarks
        }

        // Now, use the class properties for filtering
        let currentShape = self.selectedShapeId
        let currentSize = self.selectedSizeCategory
        let currentLocation = self.selectedLocation
        let currentFieldMarks = self.selectedFieldMarks
        
        // 2. Prepare Date Logic
        var searchMonth: Int?
        if let dateString = data.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM yyyy"
            if let date = formatter.date(from: dateString) {
                searchMonth = Calendar.current.component(.month, from: date)
            }
        }
        
        var scoredBirds: [(bird: ReferenceBird, score: Double, breakdown: String)] = []
        
        // 3. Scoring Loop
        for bird in allBirds {
            var score = 0.0
            var breakdownParts: [String] = []
            
            // A. Location (Soft Penalty)
            if let loc = currentLocation, !bird.validLocations.contains(loc) {
                score -= 5
                breakdownParts.append("Wrong Location (-30)")
            }
            
            // B. Seasonality
            if let month = searchMonth, let validMonths = bird.validMonths, !validMonths.contains(month) {
                score -= 50
                breakdownParts.append("Wrong Season (-50)")
            }
            
            // C. Shape
            if let userShape = currentShape, bird.attributes.shapeId == userShape {
                score += 30
                breakdownParts.append("Shape Match (+30)")
            }
            
            // D. Size
            if let userSize = currentSize {
                let diff = abs(bird.attributes.sizeCategory - userSize)
                if diff == 0 { score += 20; breakdownParts.append("Size Match (+20)") }
                else if diff == 1 { score += 10; breakdownParts.append("Size Approx (+10)") }
                else { score -= 20; breakdownParts.append("Size Mismatch (-20)") }
            }
            
            // E. Field Marks
            if !currentFieldMarks.isEmpty {
                let pointsPerMark = 50.0 / Double(currentFieldMarks.count)
                for userMark in currentFieldMarks {
                    if let birdMark = bird.fieldMarks.first(where: { $0.area == userMark.area }) {
                        if !userMark.variant.isEmpty {
                            if userMark.variant == birdMark.variant {
                                let p = pointsPerMark * 0.6
                                score += p
                                breakdownParts.append("\(userMark.area) (+)")
                            } else {
                                score -= (pointsPerMark * 0.5)
                            }
                        }
                    }
                }
            }
            
            // F. Rarity
            if bird.attributes.rarity.lowercased() == "common" { score += 5 }
            
            let finalScore = max(0.0, score)
            let normalized = min(finalScore / 100.0, 1.0)
            
            scoredBirds.append((bird, normalized, breakdownParts.joined(separator: ", ")))
        }
        
        // 4. Sort and Store
        scoredBirds = scoredBirds.filter { $0.score > 0.3 }
        scoredBirds.sort { $0.score > $1.score }
        
        self.birdResults = scoredBirds.map { item in
            IdentificationBird(
                id: item.bird.id,
                name: item.bird.commonName,
                scientificName: item.bird.scientificName ?? "",
                confidence: item.score,
                description: item.breakdown,
                imageName: item.bird.imageName,
                scoreBreakdown: item.breakdown
            )
        }
        
        // 5. Notify Controller
        DispatchQueue.main.async {
            self.onResultsUpdated?()
        }
    }
    
    // MARK: - Helpers (Helpers)
    
    var referenceFieldMarks: [ReferenceFieldMark] {
        return masterDatabase?.reference_data.fieldMarks ?? []
    }
    
    func getBird(byName name: String) -> ReferenceBird? {
        return masterDatabase?.birds.first(where: { $0.commonName == name })
    }
    
    func addToHistory(_ item: History) {
        histories.append(item)
        saveHistory()
    }
    
    // MARK: - Persistence (Private)
    
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
        try? JSONEncoder().encode(userBirds).write(to: url)
    }
    
    private func loadHistory() -> [History] {
        let url = getDocumentsDirectory().appendingPathComponent("history.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([History].self, from: data)) ?? []
    }
    
    func saveHistory() {
        let url = getDocumentsDirectory().appendingPathComponent("history.json")
        try? JSONEncoder().encode(histories).write(to: url)
    }
}
