import Foundation
import SwiftData
import SwiftUI

@Observable
class IdentificationManager {
    var modelContext: ModelContext
    var currentSession: IdentificationSession?
    var isReloadFlowActive: Bool = false
    private var locationNameById: [UUID: String] = [:]
    var tempSelectedAreas: [String] = []
    var allShapes: [BirdShape] = []
    var selectedShapeId: String? {
            selectedShape?.id
        }
    var selectedLocationId: UUID?
    var selectedShape: BirdShape? {
        didSet {
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
    var selectedLocationData: LocationService.LocationData?
    var selectedDate: Date = Date()
    var selectedMenuOptionRawValues: [String] = []
    var results: [IdentificationCandidate] = []

    private var currentUserId: UUID? {
        UserSession.shared.currentUserID
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchShapes()
    }

    func registerLocationName(_ name: String, for id: UUID?) {
        guard let id, !name.isEmpty else { return }
        locationNameById[id] = name
    }

    func locationName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return locationNameById[id]
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
        print("DEBUG: availableShapesForSelectedSize called. Size range: \(selectedSizeRange)")

        do {
            let birdsInScope: [Bird]
            if selectedSizeRange.isEmpty {
                birdsInScope = try modelContext.fetch(FetchDescriptor<Bird>())
            } else {
                let predicate = #Predicate<Bird> { bird in
                    if let sizeCategory = bird.size_category {
                        return selectedSizeRange.contains(sizeCategory)
                    } else {
                        return false
                    }
                }
                birdsInScope = try modelContext.fetch(FetchDescriptor<Bird>(predicate: predicate))
            }

            let birdShapeIds = Set(birdsInScope.compactMap { $0.shape_id })
            var visibleShapeIds = birdShapeIds

            let needsFieldMarks = selectedMenuOptionRawValues.contains(FilterCategory.fieldMarks.rawValue)
            if needsFieldMarks {
                let marks = try modelContext.fetch(FetchDescriptor<BirdFieldMark>())
                let markShapeIds = Set(marks.compactMap { $0.shape?.id })
                let intersection = birdShapeIds.intersection(markShapeIds)
                if !intersection.isEmpty {
                    visibleShapeIds = intersection
                } else if !markShapeIds.isEmpty {
                    visibleShapeIds = markShapeIds
                }
            }

            let filtered = allShapes.filter { visibleShapeIds.contains($0.id) }
            return filtered.isEmpty ? allShapes : filtered

        } catch {
            print("Error fetching shapes for current filters: \(error)")
            return allShapes
        }
    }
  

    func updateSize(_ size: Int) {
        self.selectedSizeCategory = size
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
        if let sessionToUpdate = currentSession {
            sessionToUpdate.shape = selectedShape
            sessionToUpdate.locationId = selectedLocationId
            sessionToUpdate.locationDisplayName = selectedLocation
            registerLocationName(selectedLocation ?? "", for: selectedLocationId)
            sessionToUpdate.observationDate = selectedDate
            sessionToUpdate.sizeCategory = selectedSizeCategory
            sessionToUpdate.status = .completed
            sessionToUpdate.selectedFilterCategories = selectedMenuOptionRawValues.isEmpty ? nil : selectedMenuOptionRawValues
            sessionToUpdate.syncStatus = .pendingUpdate

            if let oldMarks = sessionToUpdate.selectedMarks {
                for oldMark in oldMarks {
                    modelContext.delete(oldMark)
                }
            }

            var updatedMarks: [IdentificationSessionFieldMark] = []
            for (_, variant) in selectedFieldMarks {
                guard let fieldMark = variant.fieldMark else { continue }
                let sessionMark = IdentificationSessionFieldMark(
                    session: sessionToUpdate,
                    fieldMark: fieldMark,
                    variant: variant,
                    area: fieldMark.area
                )
                modelContext.insert(sessionMark)
                updatedMarks.append(sessionMark)
            }
            sessionToUpdate.selectedMarks = updatedMarks
            tempSelectedAreas = updatedMarks.map { $0.area }

            let result: IdentificationResult
            if let existingResult = sessionToUpdate.result {
                result = existingResult
            } else {
                result = IdentificationResult(
                    session: sessionToUpdate,
                    ownerId: sessionToUpdate.ownerId
                )
                sessionToUpdate.result = result
            }
            result.bird = winningCandidate?.bird

            if let oldCandidates = result.candidates {
                for oldCandidate in oldCandidates {
                    modelContext.delete(oldCandidate)
                }
            }
            result.candidates = []

            var updatedCandidates: [IdentificationCandidate] = []
            for (index, candidate) in self.results.enumerated() {
                let newCandidate = IdentificationCandidate(
                    result: result,
                    bird: candidate.bird,
                    confidence: candidate.confidence,
                    rank: index + 1,
                    matchScore: candidate.matchScore
                )
                modelContext.insert(newCandidate)
                updatedCandidates.append(newCandidate)
            }
            result.candidates = updatedCandidates

            try? modelContext.save()
            
            Task {
                await queueIdentificationSync(session: sessionToUpdate)
            }
            return
        }

        let newSession = IdentificationSession(
            id: UUID(),
            ownerId: currentUserId,
            shape: selectedShape,
            locationId: selectedLocationId,
            locationDisplayName: selectedLocation,
            observationDate: selectedDate,
            status: .completed,
            sizeCategory: selectedSizeCategory,
            selectedFilterCategories: selectedMenuOptionRawValues.isEmpty ? nil : selectedMenuOptionRawValues
        )
        registerLocationName(selectedLocation ?? "", for: selectedLocationId)

        var sessionMarks: [IdentificationSessionFieldMark] = []
        for (_, variant) in selectedFieldMarks {
            guard let fieldMark = variant.fieldMark else { continue }
            let sessionMark = IdentificationSessionFieldMark(
                session: newSession,
                fieldMark: fieldMark,
                variant: variant,
                area: fieldMark.area
            )
            modelContext.insert(sessionMark)
            sessionMarks.append(sessionMark)
        }
        newSession.selectedMarks = sessionMarks
        tempSelectedAreas = sessionMarks.map { $0.area }

        let result = IdentificationResult(
            session: newSession,
            ownerId: newSession.ownerId,
            bird: winningCandidate?.bird
        )

        var finalCandidates: [IdentificationCandidate] = []
        for (index, candidate) in self.results.enumerated() {
            let newCandidate = IdentificationCandidate(
                result: result,
                bird: candidate.bird,
                confidence: candidate.confidence,
                rank: index + 1,
                matchScore: candidate.matchScore
            )
            modelContext.insert(newCandidate)
            finalCandidates.append(newCandidate)
        }
        result.candidates = finalCandidates
        newSession.result = result

        modelContext.insert(newSession)
        currentSession = newSession
        try? modelContext.save()
        
        Task {
            await queueIdentificationSync(session: newSession)
        }
    }
    
    private func queueIdentificationSync(session: IdentificationSession) async {
        guard let userId = currentUserId else {
            print("⚠️ [IdentificationManager] No current user, skipping sync")
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // 1. Sync Session
        var sessionPayload: [String: Any] = [
            "id": session.id.uuidString,
            "user_id": session.ownerId?.uuidString ?? userId.uuidString,
            "status": session.status.rawValue,
            "created_at": ISO8601DateFormatter().string(from: session.created_at),
            "updated_at": ISO8601DateFormatter().string(from: session.updated_at ?? Date())
        ]
        
        if let locationDisplayName = session.locationDisplayName {
            sessionPayload["notes"] = locationDisplayName
        }
        
        var metadata: [String: Any] = [:]
        if let shapeId = session.shape?.id {
            metadata["shapeId"] = shapeId
        }
        if let sizeCategory = session.sizeCategory {
            metadata["sizeCategory"] = sizeCategory
        }
        if let filterCategories = session.selectedFilterCategories {
            metadata["filterCategories"] = filterCategories.joined(separator: ",")
        }
        if !metadata.isEmpty {
            sessionPayload["metadata"] = metadata
        }
        
        let sessionData = try? JSONSerialization.data(withJSONObject: sessionPayload)
        print("📤 [IdentificationManager] Queuing session: \(session.id)")
        await BackgroundSyncAgent.shared.queueIdentificationSession(
            id: session.id,
            payloadData: sessionData,
            localUpdatedAt: session.updated_at,
            operation: .create
        )
        
        // Give the session a tiny head start to avoid race conditions with FK constraints on Supabase
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // 2. Sync Session Marks
        if let marks = session.selectedMarks {
            print("📤 [IdentificationManager] Queuing \(marks.count) marks")
            for mark in marks {
                let markPayload: [String: Any] = [
                    "id": mark.id.uuidString,
                    "session_id": session.id.uuidString,
                    "field_mark_id": mark.fieldMark?.id.uuidString ?? "",
                    "variant_id": mark.variant?.id.uuidString ?? "",
                    "area": mark.area,
                    "created_at": ISO8601DateFormatter().string(from: session.created_at)
                ]
                let markData = try? JSONSerialization.data(withJSONObject: markPayload)
                await BackgroundSyncAgent.shared.queueIdentificationSessionMark(
                    id: mark.id,
                    payloadData: markData,
                    localUpdatedAt: Date(),
                    operation: .create
                )
            }
        }
        
        // 3. Sync Result
        if let result = session.result {
            print("📤 [IdentificationManager] Queuing result: \(result.id)")
            let resultPayload: [String: Any] = [
                "id": result.id.uuidString,
                "session_id": session.id.uuidString,
                "owner_id": result.ownerId?.uuidString ?? userId.uuidString,
                "bird_id": result.bird?.id.uuidString ?? NSNull(),
                "created_at": ISO8601DateFormatter().string(from: result.created_at),
                "updated_at": ISO8601DateFormatter().string(from: result.updated_at ?? Date())
            ]
            let resultData = try? JSONSerialization.data(withJSONObject: resultPayload)
            await BackgroundSyncAgent.shared.queueIdentificationResult(
                id: result.id,
                payloadData: resultData,
                localUpdatedAt: result.updated_at,
                operation: .create
            )
            
            // 4. Sync Candidates
            if let candidates = result.candidates {
                print("📤 [IdentificationManager] Queuing \(candidates.count) candidates")
                for candidate in candidates {
                    let candidatePayload: [String: Any] = [
                        "id": candidate.id.uuidString,
                        "result_id": result.id.uuidString,
                        "bird_id": candidate.bird?.id.uuidString ?? NSNull(), // Changed from empty string to NSNull
                        "confidence": candidate.confidence,
                        "rank": candidate.rank ?? NSNull(),
                        "matched_features": candidate.matchScore?.matchedFeatures ?? [],
                        "mismatched_features": candidate.matchScore?.mismatchedFeatures ?? [],
                        "created_at": ISO8601DateFormatter().string(from: candidate.created_at),
                        "updated_at": ISO8601DateFormatter().string(from: candidate.updated_at ?? Date())
                    ]
                    let candidateData = try? JSONSerialization.data(withJSONObject: candidatePayload)
                    await BackgroundSyncAgent.shared.queueIdentificationCandidate(
                        id: candidate.id,
                        payloadData: candidateData,
                        localUpdatedAt: candidate.updated_at,
                        operation: .create
                    )
                }
            }
        }
    }

    func loadSessionAndFilter(session: IdentificationSession) {
        self.currentSession = session
        // Reset state manually to avoid `reset()`'s filter run.
        self.tempSelectedAreas = []
        self.selectedLocationId = nil
        self.selectedSizeCategory = nil
        self.selectedSizeRange = []
        self.selectedLocation = nil
        self.selectedLocationData = nil
        self.selectedDate = Date()
        self.results = []
        
        // This will trigger a filter run and clear field marks.
        self.selectedShape = session.shape

        // Now, load the rest of the session data.
        self.selectedSizeCategory = session.sizeCategory
        if let size = self.selectedSizeCategory {
            let minSize = max(1, size - 1)
            let maxSize = min(5, size + 1)
            self.selectedSizeRange = Array(minSize...maxSize)
        }

        self.selectedDate = session.observationDate
        self.selectedLocationId = session.locationId
        self.selectedLocation = locationName(for: session.locationId)
        self.selectedMenuOptionRawValues = session.selectedFilterCategories ?? []
        
        var newFieldMarks: [UUID: FieldMarkVariant] = [:]
        if let sessionMarks = session.selectedMarks {
            for sessionMark in sessionMarks {
                if let fieldMark = sessionMark.fieldMark, let variant = sessionMark.variant {
                    newFieldMarks[fieldMark.id] = variant
                }
            }
            self.tempSelectedAreas = sessionMarks.map { $0.area }
        }
        self.selectedFieldMarks = newFieldMarks
        
        // Finally, run the filter with the complete state.
        runFilter()
    }

    func reset() {
        currentSession = nil
        isReloadFlowActive = false
        tempSelectedAreas.removeAll()
        selectedLocationId = nil
        selectedSizeCategory = nil
        selectedSizeRange.removeAll()
        selectedLocation = nil
        selectedLocationData = nil
        selectedDate = Date()
        selectedMenuOptionRawValues = []
        results.removeAll()
        
        // Setting selectedShape to nil triggers its `didSet` observer,
        // which clears `selectedFieldMarks` and runs the filter.
        selectedShape = nil
    }
    
}
