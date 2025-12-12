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
	
	var referenceFieldMarks: [ReferenceFieldMark] {
		return model.masterDatabase?.reference_data.fieldMarks ?? []
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
		
			// Date Parsing for Seasonality
		var searchMonth: Int?
		if let dateString = data.date {
			let formatter = DateFormatter()
			formatter.dateFormat = "dd MMM yyyy"
			if let date = formatter.date(from: dateString) {
				searchMonth = Calendar.current.component(.month, from: date)
				print("📅 Filtering for Month: \(searchMonth!)")
			} else {
				print("⚠️ Date Parsing Failed for: \(dateString)")
			}
		} else {
			print("⚠️ No Date Provided")
		}
		
		var scoredBirds: [(bird: ReferenceBird, score: Double, breakdown: String)] = []
		
		for bird in allBirds {
			var score = 0.0
			var breakdownParts: [String] = []
			
				// 1. HARD FILTER: Location
			if let loc = location, !bird.validLocations.contains(loc) {
				// Skip immediately
				continue
			}
			
				// 2. SEASONALITY (Hard Penalty)
			if let month = searchMonth, let validMonths = bird.validMonths {
				if !validMonths.contains(month) {
					score -= 50
					breakdownParts.append("Wrong Season (-50)")
				}
			}
			
				// 3. SHAPE (30 pts)
			if let userShape = shape {
				if bird.attributes.shapeId == userShape {
					score += 30
					breakdownParts.append("Shape Match (+30)")
				} else {
					// Neutral or slight penalty? Keeping neutral as shapes can be ambiguous
				}
			}
			
				// 4. SIZE (20 pts)
			if let userSize = size {
				let diff = abs(bird.attributes.sizeCategory - userSize)
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
			
				// 5. FIELD MARKS (50 pts Distributed)
			if let marks = fieldMarks, !marks.isEmpty {
				let pointsPerMark = 50.0 / Double(marks.count)
				
				for userMark in marks {
					// Does the bird have this body part defined?
					if let birdMark = bird.fieldMarks.first(where: { $0.area == userMark.area }) {
						
						// A. VARIANT CHECK
						if !userMark.variant.isEmpty {
							if userMark.variant == birdMark.variant {
								let p = pointsPerMark * 0.6
								score += p
								breakdownParts.append("\(userMark.area) Variant (+\(Int(p)))")
							} else {
								let p = pointsPerMark * 0.5
								score -= p
								breakdownParts.append("\(userMark.area) Mismatch (-\(Int(p)))")
							}
						}
						
						// B. COLOR CHECK
						if !userMark.colors.isEmpty {
							let userColors = Set(userMark.colors)
							let birdColors = Set(birdMark.colors)
							let intersection = userColors.intersection(birdColors)
							
							if !intersection.isEmpty {
								// Strictness: Ratio of matched colors to what user selected
								let ratio = Double(intersection.count) / Double(userColors.count)
								let p = (pointsPerMark * 0.4) * ratio
								score += p
								breakdownParts.append("\(userMark.area) Color (+\(Int(p)))")
							}
						} else {
							// If user didn't specify color, assume neutral/match for now or ignore
							// breakdownParts.append("\(userMark.area) (Ignored Color)")
						}
						
					} else {
						// Bird doesn't have this mark defined in DB
						// Neutral or slight penalty?
					}
				}
			}
			
				// 6. RARITY BONUS
			if bird.attributes.rarity.lowercased() == "common" {
				score += 5
				breakdownParts.append("Common (+5)")
			}
			
			// Normalize Score (0.0 to 1.0) for confidence, but keep raw score for sorting logic
			// Max possible is roughly 100 + 5.
			let finalScore = max(0.0, score) // Clamp negative scores to 0 for display
			let normalized = min(finalScore / 100.0, 1.0)
			
			let breakdownString = breakdownParts.joined(separator: ", ")
			scoredBirds.append((bird, normalized, breakdownString))
		}
		
			// 3. FILTER (> 30%)
		scoredBirds = scoredBirds.filter { $0.score > 0.3 }
		
			// 4. SORT & LOG
		scoredBirds.sort { $0.score > $1.score }
		
		print("--- CALCULATION RESULTS ---")
		for item in scoredBirds {
			print("🐦 \(item.bird.commonName): \(Int(item.score * 100))%")
			print("   Breakdown: \(item.breakdown)")
		}
		print("---------------------------")
		
		self.birdResults = scoredBirds.map { item in
			IdentificationBird(
				id: item.bird.id,
				name: item.bird.commonName,
				scientificName: item.bird.scientificName ?? "",
				confidence: item.score,
				description: item.breakdown, // Using description to store breakdown for now
				imageName: item.bird.imageName,
				scoreBreakdown: item.breakdown
			)
		}
		
		DispatchQueue.main.async {
			self.onResultsUpdated?()
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
    
    func getBird(byName name: String) -> ReferenceBird? {
        return model.masterDatabase?.birds.first(where: { $0.commonName == name })
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
