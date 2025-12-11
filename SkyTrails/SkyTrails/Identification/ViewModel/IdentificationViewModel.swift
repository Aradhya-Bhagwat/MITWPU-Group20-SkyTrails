import Foundation

class ViewModel {
    var selectedSizeCategory: Int?
    var selectedShapeId: String?
    var selectedLocation: String?
    var selectedFieldMarks: [FieldMarkData] = []

    private var model = IdentificationModels()
    var data = IdentificationData() // Keeping this if it's used elsewhere, but data should come from model now
    
    // filtered results
    var filteredBirds: [MasterBird] = []

    init() {
        print("📌 ViewModel initialized")
        // Initialize with all birds
        if let allBirds = model.masterDatabase?.birds {
            filteredBirds = allBirds
            updateBirdResults()
        }
    }
   

    var histories: [History] {
        get { model.histories }
        set {
            model.histories = newValue
            model.saveHistory() // Persist changes
        }
    }

    var fieldMarkOptions: [FieldMarkType] {
        get { model.fieldMarkOptions }
        set { model.fieldMarkOptions = newValue }
    }
    
    // ... (Existing properties) ...
    
    // MARK: - History Management
    
    func addToHistory(_ item: History) {
        model.histories.append(item)
        model.saveHistory()
    }
    
    // MARK: - Database Management
    
    func addBirdToDatabase(_ bird: MasterBird) {
        model.addBird(bird)
        // Refresh filtering if needed
        if let allBirds = model.masterDatabase?.birds {
            filteredBirds = allBirds
            updateBirdResults()
        }
    }
    
    func deleteBirdFromDatabase(id: String) {
        model.deleteBird(id: id)
        // Refresh filtering
        if let allBirds = model.masterDatabase?.birds {
            filteredBirds = allBirds
            updateBirdResults()
        }
    }


    var birdShapes: [BirdShape] {
        get { model.birdShapes }
        set { model.birdShapes = newValue }
    }

    var fieldMarks: [ChooseFieldMark] {
        get { model.chooseFieldMarks }
        set { model.chooseFieldMarks = newValue }
    }

    var birdResults: [BirdResult] {
        get { model.birdResults }
        set { model.birdResults = newValue }
    }
    
    // MARK: - Filtering Logic
    
    func filterBirds(shape: String?, size: Int?, location: String?, fieldMarks: [FieldMarkData]?) {
        guard let db = model.masterDatabase else { return }
        
        var results = db.birds
        
        // 1. Filter by Shape
        if let shape = shape {
            results = results.filter { $0.attributes.shapeId == shape }
        }
        
        // 2. Filter by Size
        // Assuming strict match, or range logic could be added here
        if let size = size {
            results = results.filter { $0.attributes.sizeCategory == size }
        }
        
        // 3. Filter by Location
        if let location = location {
            results = results.filter { $0.validLocations.contains(location) }
        }
        
        // 4. Filter by Field Marks
        if let marks = fieldMarks, !marks.isEmpty {
            results = results.filter { bird in
                // Bird must have ALL the selected marks (AND logic)
                for mark in marks {
                    let hasMark = bird.fieldMarks.contains { birdMark in
                        // Comparing area.
                        // If variant is empty (generic area selection), we ignore variant matching.
                        let areaMatch = birdMark.area == mark.area
                        let variantMatch = mark.variant.isEmpty || birdMark.variant == mark.variant
                        
                        // If user selected colors, check overlap
                        var colorMatch = true
                        if !mark.colors.isEmpty {
                            let birdColors = Set(birdMark.colors)
                            let selectedColors = Set(mark.colors)
                            // If bird has ANY of the selected colors for this mark? Or ALL?
                            // Usually "Red Head" means the head is red.
                            // If user says "Red", bird head must contain "Red".
                            colorMatch = !birdColors.intersection(selectedColors).isEmpty
                        }
                        
                        return areaMatch && variantMatch && colorMatch
                    }
                    if !hasMark { return false }
                }
                return true
            }
        }
        
        self.filteredBirds = results
        updateBirdResults()
    }
    
    private func updateBirdResults() {
        // specific logic to calculate match percentage could go here
        // for now, just mapping them to BirdResult with 100% or based on filter count
        
        self.birdResults = filteredBirds.map { bird in
            BirdResult(name: bird.commonName, percentage: 100, imageView: bird.imageName, masterBirdId: bird.id)
        }
    }
    
    func getBird(by id: String) -> MasterBird? {
        return model.masterDatabase?.birds.first(where: { $0.id == id })
    }
}

