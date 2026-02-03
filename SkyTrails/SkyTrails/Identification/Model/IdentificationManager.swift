import Foundation
import SwiftData
import SwiftUI

@Observable
class IdentificationManager {
    var modelContext: ModelContext
    var tempSelectedAreas: [String] = []
    // Core Data for the Filter
    var allShapes: [BirdShape] = []
    var selectedShapeId: String? {
            selectedShape?.id
        }
    // Prediction relies on these properties:
    var selectedShape: BirdShape? {
        didSet {
            // Reset field marks when shape changes to avoid illogical combinations
            selectedFieldMarks.removeAll()
            runFilter()
        }
    }
    func filterBirds(shape: String?, size: Int?, location: String?, fieldMarks: [Any]) {
            
            runFilter()
        }
    var selectedFieldMarks: [UUID: FieldMarkVariant] = [:]
    var selectedSizeCategory: Int?
    var selectedSizeRange: [Int] = []
    var selectedLocation: String?
    var selectedDate: Date = Date()
    
    // Results stored for the UI to observe
    var results: [IdentificationCandidate] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchShapes()
    }
    
    func fetchShapes() {
        do {
            let descriptor = FetchDescriptor<BirdShape>(sortBy: [SortDescriptor(\.name)])
            self.allShapes = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading shapes: \(error)")
        }
    }

    
    func availableShapesForSelectedSize() -> [BirdShape] {
        guard let size = selectedSizeCategory else { return allShapes }
        
        do {
            let birdDescriptor = FetchDescriptor<Bird>(
                predicate: #Predicate<Bird> { $0.size_category == size }
            )
            let birdsInSize = try modelContext.fetch(birdDescriptor)
            let validShapeIds = Set(birdsInSize.compactMap { $0.shape_id })
            
            return allShapes.filter { validShapeIds.contains($0.id) }
        } catch {
            return allShapes
        }
    }
  

    func updateSize(_ size: Int) {
        self.selectedSizeCategory = size
        
        // Logic: specific size plus/minus one for a broader search
        let minSize = max(1, size - 1)
        let maxSize = min(5, size + 1)
        self.selectedSizeRange = Array(minSize...maxSize)
        
        runFilter()
    }

    func runFilter() {
        guard let allBirds = try? modelContext.fetch(FetchDescriptor<Bird>()) else { return }
        
        var candidates: [IdentificationCandidate] = []
        let searchMonth = Calendar.current.component(.month, from: selectedDate)
        
        for bird in allBirds {
            var score = 0.0
            var matchedFeats: [String] = []
            var mismatchedFeats: [String] = []
            
            // 1. Shape Logic (Strict matching)
            if let userShapeId = selectedShape?.id {
                if bird.shape_id == userShapeId {
                    score += 30
                    matchedFeats.append("Shape")
                } else {
                    continue // Ignore birds that don't match the selected shape
                }
            }
            
            // 2. Size Scoring (Fuzzy +/- 1 logic)
            if let birdSize = bird.size_category, !selectedSizeRange.isEmpty {
                if birdSize == selectedSizeCategory {
                    score += 20
                    matchedFeats.append("Size")
                } else if selectedSizeRange.contains(birdSize) {
                    score += 10 // Partial match for the range
                    matchedFeats.append("Approx. Size")
                } else {
                    score -= 20
                    mismatchedFeats.append("Size")
                }
            }

            // 3. Location & Season
            if let loc = selectedLocation, let birdLocs = bird.validLocations {
                if !birdLocs.contains(loc) {
                    score -= 30
                    mismatchedFeats.append("Location")
                }
            }
            
            if let birdMonths = bird.validMonths {
                if !birdMonths.contains(searchMonth) {
                    score -= 50
                    mismatchedFeats.append("Season")
                }
            }
            
            // 4. Field Mark Matching (AREA + VARIANT) - UPDATED
            if !selectedFieldMarks.isEmpty,
               let birdMarkData = bird.fieldMarkData {

                for (_, userVariant) in selectedFieldMarks {
                    guard let userFieldMark = userVariant.fieldMark else { continue }
                    let areaName = userFieldMark.area

                    // Check if bird has this AREA with this VARIANT
                    let matched = birdMarkData.contains {
                        $0.area == areaName && $0.variantId == userVariant.id
                    }

                    if matched {
                        score += 25
                        matchedFeats.append("\(areaName): \(userVariant.name)")
                    } else {
                        score -= 10
                        mismatchedFeats.append(areaName)
                    }
                }
            }

            
            // Normalize score and create candidate if threshold met
            let finalScore = max(0.0, min(score / 100.0, 1.0))
            
            if finalScore > 0.1 {
                let matchScore = MatchScore(
                    matchedFeatures: matchedFeats,
                    mismatchedFeatures: mismatchedFeats,
                    score: finalScore
                )
                
                let candidate = IdentificationCandidate(
                    bird: bird,
                    confidence: finalScore,
                    matchScore: matchScore
                )
                candidates.append(candidate)
            }
        }
        
        self.results = candidates.sorted { $0.confidence > $1.confidence }
    }

    func toggleVariant(_ variant: FieldMarkVariant, for mark: BirdFieldMark) {
        if selectedFieldMarks[mark.id] == variant {
            selectedFieldMarks.removeValue(forKey: mark.id)
        } else {
            selectedFieldMarks[mark.id] = variant
        }
        runFilter()
    }

    func saveSession(winningCandidate: IdentificationCandidate?) {
        let newSession = IdentificationSession(
            id: UUID(),
            userId: UUID(),
            shape: selectedShape,
            locationId: nil,
            observationDate: selectedDate,
            status: .completed
        )

        for (_, variant) in selectedFieldMarks {
            if let fieldMark = variant.fieldMark {
                let sessionMark = IdentificationSessionFieldMark(
                    session: newSession,
                    fieldMark: fieldMark,
                    variant: variant,
                    area: fieldMark.area
                )
                modelContext.insert(sessionMark)
            }
        }

        let result = IdentificationResult(
            session: newSession,
            userId: newSession.userId,
            bird: winningCandidate?.bird
        )
        newSession.result = result
        
        modelContext.insert(newSession)
        try? modelContext.save()
    }
}
