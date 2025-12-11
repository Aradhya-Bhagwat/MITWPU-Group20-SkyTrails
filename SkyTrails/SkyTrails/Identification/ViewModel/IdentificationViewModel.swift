import Foundation

class ViewModel {
	
		// MARK: - State
	var selectedSizeCategory: Int?
	var selectedShapeId: String?
	var selectedLocation: String?
	var selectedFieldMarks: [FieldMarkData] = []
	
		// Reference to Data Manager
	private var model = IdentificationModels()
	var onResultsUpdated: (() -> Void)?
	var data = IdentificationData()
	
		// MARK: - Outputs
		// This is what the Results View Controller should read
	var birdResults: [IdentificationBird] = []
	
		// Helper accessors for UI
	var birdShapes: [BirdShape] {
		get { model.birdShapes }
	}
	
	var fieldMarkOptions: [FieldMarkType] {
		get { model.fieldMarkOptions }
		set { model.fieldMarkOptions = newValue }
	}
	
	var fieldMarks: [ChooseFieldMark] {
		get { model.chooseFieldMarks }
		set { model.chooseFieldMarks = newValue }
	}
	
	var histories: [History] {
		get { model.histories }
		set {
			model.histories = newValue
			model.saveHistory()
		}
	}
	
	init() {
		print("📌 ViewModel initialized")
	}
	
		// MARK: - Filtering Algorithm
	
		/// Runs the weighted scoring algorithm to find the best matches
	func filterBirds(shape: String?, size: Int?, location: String?, fieldMarks: [FieldMarkData]?) {
		guard let allBirds = model.masterDatabase?.birds else { return }
		
			// Update Local State
		self.selectedShapeId = shape
		self.selectedSizeCategory = size
		self.selectedLocation = location
		self.selectedFieldMarks = fieldMarks ?? []
		
		var scoredBirds: [(bird: ReferenceBird, score: Double, details: String)] = []
		
			// 1. HARD FILTER: Location (Pass/Fail)
			// If bird is not in the location, it is excluded immediately.
		let locationFiltered = allBirds.filter { bird in
			guard let loc = location else { return true }
			return bird.validLocations.contains(loc)
		}
		
			// 2. SCORING LOOP
		for bird in locationFiltered {
			var score = 0.0
			var maxPossibleScore = 0.0
			var matchDetails: [String] = []
			
				// --- CRITERIA 1: SHAPE (Weight: 30) ---
			if let userShape = shape {
				maxPossibleScore += 30
				if bird.attributes.shapeId == userShape {
					score += 30
					matchDetails.append("Shape")
				}
			}
			
				// --- CRITERIA 2: SIZE (Weight: 20) ---
			if let userSize = size {
				maxPossibleScore += 20
				let diff = abs(bird.attributes.sizeCategory - userSize)
				
				if diff == 0 {
					score += 20 // Exact match
					matchDetails.append("Size")
				} else if diff == 1 {
					score += 10 // Close enough
				}
			}
			
				// --- CRITERIA 3: FIELD MARKS (Weight: 50) ---
			if let marks = fieldMarks, !marks.isEmpty {
				let pointsPerMark = 50.0 / Double(marks.count)
				
				for userMark in marks {
					maxPossibleScore += pointsPerMark
					
						// Check if bird has this mark
					if let birdMark = bird.fieldMarks.first(where: { $0.area == userMark.area }) {
						var markScore = pointsPerMark * 0.4 // Base score for Area match
						var specificMatch = false
						
							// Variant Check (if user specified one)
						if userMark.variant.isEmpty || userMark.variant == birdMark.variant {
							markScore += pointsPerMark * 0.3
							specificMatch = true
						}
						
							// Color Check (if user specified colors)
						if userMark.colors.isEmpty {
							markScore += pointsPerMark * 0.3
						} else {
							let birdColors = Set(birdMark.colors)
							let userColors = Set(userMark.colors)
							if !birdColors.isDisjoint(with: userColors) {
								markScore += pointsPerMark * 0.3
								specificMatch = true
							}
						}
						
						score += markScore
						if specificMatch {
							matchDetails.append(userMark.area)
						}
					}
				}
			}
			
				// Calculate Final Percentage
			if maxPossibleScore > 0 {
					// Rarity Bonus (Common birds get a 5% boost)
				if bird.attributes.rarity.lowercased() == "common" {
					score += (maxPossibleScore * 0.05)
				}
				
				let finalScore = score / maxPossibleScore
				let detailsString = matchDetails.isEmpty ? "Partial Match" : matchDetails.joined(separator: ", ")
				scoredBirds.append((bird, finalScore, detailsString))
			} else {
					// No filters applied: Return everything with 0 score (or 100 if you prefer)
				scoredBirds.append((bird, 0.0, "No Filters"))
			}
			
			DispatchQueue.main.async {
				self.onResultsUpdated?()
			}
		}
		
			// 3. SORT & MAP
		scoredBirds.sort { $0.score > $1.score }
		
		self.birdResults = scoredBirds.map { item in
			IdentificationBird(
				id: item.bird.id,
				name: item.bird.commonName,
				scientificName: item.bird.scientificName ?? "",
				confidence: min(item.score, 1.0),
				description: item.details,
				imageName: item.bird.imageName
			)
		}
	}
	
		// MARK: - Legacy / Helper Methods
	
	func addToHistory(_ item: History) {
		model.histories.append(item)
		model.saveHistory()
	}
	
	func getBird(by id: String) -> ReferenceBird? {
		return model.masterDatabase?.birds.first(where: { $0.id == id })
	}
	
	func addBirdToDatabase(_ bird: ReferenceBird) {
		model.addBird(bird)
			// Re-run filter to include new bird
		filterBirds(shape: selectedShapeId, size: selectedSizeCategory, location: selectedLocation, fieldMarks: selectedFieldMarks)
	}
	
	func deleteBirdFromDatabase(id: String) {
		model.deleteBird(id: id)
			// Re-run filter
		filterBirds(shape: selectedShapeId, size: selectedSizeCategory, location: selectedLocation, fieldMarks: selectedFieldMarks)
	}
}
