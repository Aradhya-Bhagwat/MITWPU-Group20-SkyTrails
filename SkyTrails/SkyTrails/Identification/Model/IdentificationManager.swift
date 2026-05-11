import Foundation
import SwiftData
import SwiftUI
import CoreLocation

@Observable
class IdentificationManager {
    var modelContext: ModelContext
    var currentSession: IdentificationSession?
    var isReloadFlowActive: Bool = false
    private let seeder = IdentificationSeeder()
    private var locationNameById: [UUID: String] = [:]
    var tempSelectedAreas: [String] = []
    var allShapes: [BirdShape] = []
    var selectedShapeId: String? {
        selectedShape?.bird_shape_id
    }
    var selectedLocationId: UUID?
    var selectedShape: BirdShape? {
        didSet {
            selectedFieldMarks.removeAll()
            runFilter()
        }
    }
    
    var selectedShapeRepresentativeImageName: String? {
        guard let shape = selectedShape else { return nil }
        let targetShapeId = shape.bird_shape_id
        do {
            let predicate = #Predicate<Bird> { bird in
                bird.shape_id == targetShapeId
            }
            let descriptor = FetchDescriptor<Bird>(predicate: predicate)
            let birds = try modelContext.fetch(descriptor)
            return birds.first?.staticImageName
        } catch {
            return nil
        }
    }
    func filterBirds(shape: String?, size: Int?, location: String?, fieldMarks: [Any]) {
            
            runFilter()
        }
    var selectedFieldMarks: [UUID: FieldMarkVariant] = [:]
    var selectedOverlayColors: [UUID: UIColor] = [:]
    
    func setColor(_ color: UIColor, for variant: FieldMarkVariant, in mark: BirdFieldMark) {
        selectedOverlayColors[mark.bird_field_mark_id] = color
    }
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
    
    private var userLocationCoordinate: CLLocationCoordinate2D?
    private var mlPredictedBirdIds: Set<UUID> = []
    private var isFetchingMLData = false
    private let locationService = LocationService.shared
    private let colorMatchWeight: Double = 1.0

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
            try seeder.seed(context: modelContext)
            let descriptor = FetchDescriptor<BirdShape>(sortBy: [SortDescriptor(\.name)])
            self.allShapes = try modelContext.fetch(descriptor)
        } catch {
        }
    }

    
    func availableShapesForSelectedSize() -> [BirdShape] {
        do {
            let allBirds = try modelContext.fetch(FetchDescriptor<Bird>())
            
            let relevantBirds: [Bird]
            if let size = selectedSizeCategory {
                let minSize = max(1, size - 1)
                let maxSize = min(5, size + 1)
                let range = minSize...maxSize
                relevantBirds = allBirds.filter { bird in
                    if let birdSize = bird.size_category {
                        return range.contains(birdSize)
                    }
                    return false
                }
            } else {
                relevantBirds = allBirds
            }
            
            let birdShapeIds = Set(relevantBirds.compactMap { $0.shape?.bird_shape_id ?? $0.shape_id })
            
            if birdShapeIds.isEmpty {
                return allShapes
            }
            
            let filtered = allShapes.filter { birdShapeIds.contains($0.bird_shape_id) }
            return filtered.isEmpty ? allShapes : filtered

        } catch {
            return allShapes
        }
    }
    
    func updateSelectedLocation(_ locationName: String?) {
        self.selectedLocation = locationName
        self.userLocationCoordinate = nil
        self.mlPredictedBirdIds = []
        
        guard let name = locationName, !name.isEmpty else { return }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let locationData = try await self.locationService.geocode(query: name)
                self.userLocationCoordinate = CLLocationCoordinate2D(
                    latitude: locationData.lat,
                    longitude: locationData.lon
                )
                self.fetchMLPredictedBirds()
            } catch {
            }
        }
    }
    
    private func fetchMLPredictedBirds() {
        guard let coordinate = userLocationCoordinate, !isFetchingMLData else { return }
        isFetchingMLData = true
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            let week = Calendar.current.component(.weekOfYear, from: self.selectedDate)
            let radiusInKm: Double = 50.0
            
            let descriptor = FetchDescriptor<Hotspot>()
            
            do {
                let allHotspots = try self.modelContext.fetch(descriptor)
                let queryLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                
                let nearbyHotspots = allHotspots.filter { hotspot in
                    let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
                    return hotspotLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
                }
                
                var predictedIds: Set<UUID> = []
                
                for hotspot in nearbyHotspots {
                    guard let speciesList = hotspot.speciesList else { continue }
                    for presence in speciesList {
                        if let validWeeks = presence.validWeeks,
                           validWeeks.contains(week),
                           let bird = presence.bird {
                            predictedIds.insert(bird.bird_id)
                        }
                    }
                }
                
                self.mlPredictedBirdIds = predictedIds
                self.runFilter()
            } catch {
            }
            
            self.isFetchingMLData = false
        }
    }
    
    private func getMLLocationScore(for bird: Bird) -> Double {
        if mlPredictedBirdIds.contains(bird.bird_id) {
            return 15.0
        }
        return 0.0
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
        
        let selectedId = selectedShape?.bird_shape_id ?? "NIL"
        
        // SELF-HEALING: If we see NIL for birds, trigger a repair
        let needsRepair = allBirds.contains { $0.shape == nil && $0.shape_id == nil }
        if needsRepair && !allBirds.isEmpty {
             try? seeder.seed(context: modelContext)
        }

        let matchingBirds = allBirds.filter { ($0.shape?.bird_shape_id ?? $0.shape_id) == selectedId }

        var candidates: [IdentificationCandidate] = []
        let searchMonth = Calendar.current.component(.month, from: selectedDate)
        
        for bird in allBirds {
            var score = 0.0
            var matchedFeats: [String] = []
            var mismatchedFeats: [String] = []
            
            // 1. Shape Match (The Entry Ticket)
            if let userShapeId = selectedShape?.bird_shape_id {
                if (bird.shape?.bird_shape_id ?? bird.shape_id) == userShapeId {
                    score += 40
                    matchedFeats.append("Shape")
                } else {
                    continue // Only show shape-matched birds if a shape is selected
                }
            }
            
            // 2. Size Match
            if let birdSize = bird.size_category, !selectedSizeRange.isEmpty {
                if birdSize == selectedSizeCategory {
                    score += 20
                    matchedFeats.append("Size")
                } else if selectedSizeRange.contains(birdSize) {
                    score += 10
                    matchedFeats.append("Approx. Size")
                }
            }
            
            // 3. Field Marks & Colors (High Granularity)
            if !selectedFieldMarks.isEmpty {
                let birdLinks = bird.fieldMarkLinks ?? []
                for (markId, userVariant) in selectedFieldMarks {
                    guard let userFieldMark = userVariant.fieldMark else { continue }
                    let areaName = userFieldMark.area
                    
                    let link = birdLinks.first { 
                        $0.area == areaName && $0.variant?.field_mark_variant_id == userVariant.field_mark_variant_id 
                    }
                    
                    if link != nil {
                        score += 20 // Base mark match
                        matchedFeats.append("\(areaName): \(userVariant.name)")
                        
                        if let userColor = selectedOverlayColors[markId],
                           let birdColorHex = link?.color_hex {
                            let points = ColorFamilyMatcher.points(userHex: userColor.toHexString(), birdHex: birdColorHex)
                            if points > 0 {
                                let colorBonus = Double(points) * 1.5 // Max 15 points
                                score += colorBonus
                                matchedFeats.append("\(areaName) color match")
                            }
                        }
                    } else {
                        mismatchedFeats.append(areaName)
                    }
                }
            }
            
            // 4. Probability Multipliers (Location & Season)
            var multiplier = 1.0
            
            let mlScore = getMLLocationScore(for: bird)
            if mlScore > 0 {
                multiplier += 0.2 // 20% boost for likely location
                matchedFeats.append("Likely Location")
            }
            
            if let birdMonths = bird.validMonths {
                if !birdMonths.contains(searchMonth) {
                    multiplier *= 0.5 // 50% penalty for out-of-season
                    mismatchedFeats.append("Out of Season")
                } else {
                    multiplier += 0.1 // 10% boost for in-season
                }
            }
            
            // 5. Deterministic Tie-Breaker (Unique to every bird)
            let hashVal = abs(bird.bird_id.uuidString.hashValue % 100)
            let tieBreaker = Double(hashVal) / 10000.0
            
            let rawScore = (score * multiplier) + tieBreaker
            let confidence = max(0.05, min(rawScore / 100.0, 0.98)) // Cap raw score at 98%
            
            let matchScore = MatchScore(
                matchedFeatures: matchedFeats,
                mismatchedFeatures: mismatchedFeats,
                score: confidence
            )
            
            candidates.append(IdentificationCandidate(
                bird: bird,
                confidence: confidence,
                matchScore: matchScore
            ))
        }
        
        // 6. Precision Ranking Curve (Ensures no two birds share a percentage)
        let sorted = candidates.sorted { $0.confidence > $1.confidence }
        
        if let bestConfidence = sorted.first?.confidence, bestConfidence > 0.05 {
            for (index, candidate) in sorted.enumerated() {
                // 1. Calculate relative position (0.0 to 1.0)
                let relativeScore = candidate.confidence / bestConfidence
                
                // 2. Apply a Power Curve to stretch the differences
                // This makes close matches (e.g. 0.9 vs 0.88) spread out more (e.g. 95% vs 88%)
                let curvedScore = pow(relativeScore, 1.5)
                
                // 3. Map to a high-quality display range (e.g. 15% to 96%)
                let baseDisplay = 0.15 + (curvedScore * 0.81)
                
                // 4. Apply Ranking Decay
                let decay = Double(index) * 0.002
                
                let finalConfidence = max(0.05, baseDisplay - decay)
                candidate.confidence = min(0.99, finalConfidence)
            }
        }
        
        self.results = sorted
    }
    
    private func tokenSet(from raw: String?) -> Set<String> {
        guard let raw, !raw.isEmpty else { return [] }
        let lower = raw.lowercased()
        let separators = CharacterSet.alphanumerics.inverted
        let parts = lower.components(separatedBy: separators)
        return Set(parts.filter { !$0.isEmpty })
    }

    func toggleVariant(_ variant: FieldMarkVariant, for mark: BirdFieldMark) {
        if selectedFieldMarks[mark.bird_field_mark_id] == variant {
            selectedFieldMarks.removeValue(forKey: mark.bird_field_mark_id)
        } else {
            selectedFieldMarks[mark.bird_field_mark_id] = variant
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

            var marksToDelete: [UUID] = []
            if let oldMarks = sessionToUpdate.selectedMarks {
                for oldMark in oldMarks {
                    marksToDelete.append(oldMark.identification_session_mark_id)
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
                if let color = selectedOverlayColors[fieldMark.bird_field_mark_id] {
                    sessionMark.overlayColorHex = color.toHexString()
                }
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
                    user_id: sessionToUpdate.user_id
                )
                IdentificationRelationshipBinder.bind(result, to: sessionToUpdate)
            }
            result.bird = winningCandidate?.bird

            var candidatesToDelete: [UUID] = []
            if let oldCandidates = result.candidates {
                for oldCandidate in oldCandidates {
                    candidatesToDelete.append(oldCandidate.identification_candidate_id)
                    modelContext.delete(oldCandidate)
                }
            }
            result.candidates = []

            var updatedCandidates: [IdentificationCandidate] = []
            for (index, candidate) in self.results.prefix(50).enumerated() {
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
                for markId in marksToDelete {
                    await BackgroundSyncAgent.shared.queueIdentificationSessionMark(
                        id: markId,
                        payloadData: nil,
                        localUpdatedAt: Date(),
                        operation: .delete
                    )
                }
                for candidateId in candidatesToDelete {
                    await BackgroundSyncAgent.shared.queueIdentificationCandidate(
                        id: candidateId,
                        payloadData: nil,
                        localUpdatedAt: Date(),
                        operation: .delete
                    )
                }
                await queueIdentificationSync(session: sessionToUpdate)
            }
            return
        }

        let newSession = IdentificationSession(
            identification_session_id: UUID(),
            user_id: currentUserId,
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
            if let color = selectedOverlayColors[fieldMark.bird_field_mark_id] {
                sessionMark.overlayColorHex = color.toHexString()
            }
            modelContext.insert(sessionMark)
            sessionMarks.append(sessionMark)
        }
        newSession.selectedMarks = sessionMarks
        tempSelectedAreas = sessionMarks.map { $0.area }

        let result = IdentificationResult(
            user_id: newSession.user_id,
            bird: winningCandidate?.bird
        )

        var finalCandidates: [IdentificationCandidate] = []
        for (index, candidate) in self.results.prefix(50).enumerated() {
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
        IdentificationRelationshipBinder.bind(result, to: newSession)

        modelContext.insert(newSession)
        currentSession = newSession
        try? modelContext.save()
        
        Task {
            await queueIdentificationSync(session: newSession)
        }
    }
    
    @MainActor
    private func queueIdentificationSync(session: IdentificationSession) async {
        guard let userId = currentUserId else {
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var sessionPayload: [String: Any] = [
            "identification_session_id": session.identification_session_id.uuidString,
            "user_id": session.user_id?.uuidString ?? userId.uuidString,
            "status": session.status.rawValue,
            "created_at": ISO8601DateFormatter().string(from: session.created_at),
            "updated_at": ISO8601DateFormatter().string(from: session.updated_at ?? Date())
        ]
        
        if let locationDisplayName = session.locationDisplayName {
            sessionPayload["notes"] = locationDisplayName
        }
        
        var metadata: [String: Any] = [:]
        if let shapeId = session.shape?.bird_shape_id {
            metadata["shapeId"] = shapeId
        }
        if let sizeCategory = session.sizeCategory {
            metadata["sizeCategory"] = sizeCategory
        }
        if let filterCategories = session.selectedFilterCategories {
            metadata["filterCategories"] = filterCategories.joined(separator: ",")
        }
        metadata["observationDate"] = ISO8601DateFormatter().string(from: session.observationDate)
        if !metadata.isEmpty {
            sessionPayload["metadata"] = metadata
        }
        
        let sessionData = try? JSONSerialization.data(withJSONObject: sessionPayload)
        await BackgroundSyncAgent.shared.queueIdentificationSession(
            id: session.identification_session_id,
            payloadData: sessionData,
            localUpdatedAt: session.updated_at,
            operation: .create
        )
        try? await Task.sleep(nanoseconds: 500_000_000)
        if let marks = session.selectedMarks {
            for mark in marks {
                let markPayload: [String: Any] = [
                    "identification_session_mark_id": mark.identification_session_mark_id.uuidString,
                    "identification_session_id": session.identification_session_id.uuidString,
                    "field_mark_id": mark.fieldMark?.bird_field_mark_id.uuidString ?? "",
                    "variant_id": mark.variant?.field_mark_variant_id.uuidString ?? "",
                    "area": mark.area,
                    "color_hex": mark.overlayColorHex ?? NSNull(),
                    "created_at": ISO8601DateFormatter().string(from: session.created_at)
                ]
                let markData = try? JSONSerialization.data(withJSONObject: markPayload)
                await BackgroundSyncAgent.shared.queueIdentificationSessionMark(
                    id: mark.identification_session_mark_id,
                    payloadData: markData,
                    localUpdatedAt: Date(),
                    operation: .create
                )
            }
        }
        if let result = session.result {
            let resultPayload: [String: Any] = [
                "identification_result_id": result.identification_result_id.uuidString,
                "identification_session_id": session.identification_session_id.uuidString,
                "owner_id": result.user_id?.uuidString ?? userId.uuidString,
                "bird_id": result.bird?.bird_id.uuidString ?? NSNull(),
                "created_at": ISO8601DateFormatter().string(from: result.created_at),
                "updated_at": ISO8601DateFormatter().string(from: result.updated_at ?? Date())
            ]
            let resultData = try? JSONSerialization.data(withJSONObject: resultPayload)
            await BackgroundSyncAgent.shared.queueIdentificationResult(
                id: result.identification_result_id,
                payloadData: resultData,
                localUpdatedAt: result.updated_at,
                operation: .create
            )
            if let candidates = result.candidates {
                for candidate in candidates {
                    let candidatePayload: [String: Any] = [
                        "identification_candidate_id": candidate.identification_candidate_id.uuidString,
                        "identification_result_id": result.identification_result_id.uuidString,
                        "bird_id": candidate.bird?.bird_id.uuidString ?? NSNull(),
                        "confidence": candidate.confidence,
                        "confidence_rank": candidate.rank ?? NSNull(),
                        "matched_features": candidate.matchScore?.matchedFeatures ?? [],
                        "mismatched_features": candidate.matchScore?.mismatchedFeatures ?? [],
                        "created_at": ISO8601DateFormatter().string(from: candidate.created_at),
                        "updated_at": ISO8601DateFormatter().string(from: candidate.updated_at ?? Date())
                    ]
                    let candidateData = try? JSONSerialization.data(withJSONObject: candidatePayload)
                    await BackgroundSyncAgent.shared.queueIdentificationCandidate(
                        id: candidate.identification_candidate_id,
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
        self.tempSelectedAreas = []
        self.selectedLocationId = nil
        self.selectedSizeCategory = nil
        self.selectedSizeRange = []
        self.selectedLocation = nil
        self.selectedLocationData = nil
        self.selectedDate = Date()
        self.results = []
        self.selectedShape = session.shape
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
        var newOverlayColors: [UUID: UIColor] = [:]
        if let sessionMarks = session.selectedMarks {
            for sessionMark in sessionMarks {
                if let fieldMark = sessionMark.fieldMark, let variant = sessionMark.variant {
                    newFieldMarks[fieldMark.bird_field_mark_id] = variant
                    if let hex = sessionMark.overlayColorHex, let color = UIColor.fromHex(hex) {
                        newOverlayColors[fieldMark.bird_field_mark_id] = color
                    }
                }
            }
            self.tempSelectedAreas = sessionMarks.map { $0.area }
        }
        self.selectedFieldMarks = newFieldMarks
        self.selectedOverlayColors = newOverlayColors
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
        selectedShape = nil
    }
    
}
