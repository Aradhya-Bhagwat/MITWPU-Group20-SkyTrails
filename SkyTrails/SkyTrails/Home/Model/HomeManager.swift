//
//  HomeManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/01/26.
//

import Foundation
import CoreLocation

class HomeManager {
    
    static let shared = HomeManager()
    
    var coreHomeData: CoreHomeData?
    var newsResponse: NewsResponse?
    var predictionData: PredictionDataWrapper?
    var spotSpeciesCountCache: [String: Int] = [:]

    
    private init() {
        loadData()
    }
    
    // MARK: - Persistence
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            if let coreData = coreHomeData {
                let url = getDocumentsDirectory().appendingPathComponent("home_data.json")
                let data = try encoder.encode(coreData)
                try data.write(to: url)
            }
        } catch {
            print("Error saving Home data: \(error)")
        }
    }
    
    public func loadData() {
        let decoder = JSONDecoder()
        
        // --- 1. Load Core Home Data ---
        var loadedFromDocuments = false
        var loadedCoreData = false
        let coreDataURL = getDocumentsDirectory().appendingPathComponent("home_data.json")
        
        // Try Documents
        if let data = try? Data(contentsOf: coreDataURL) {
            do {
                self.coreHomeData = try decoder.decode(CoreHomeData.self, from: data)
                loadedCoreData = true
                loadedFromDocuments = true
            } catch {
                print("CRITICAL ERROR: Failed to decode home_data.json from Documents: \(error)")
            }
        }
        
        // Fallback: Bundle
        if !loadedCoreData {
            if let bundleURL = Bundle.main.url(forResource: "home_data", withExtension: "json"),
               let data = try? Data(contentsOf: bundleURL) {
                do {
                    self.coreHomeData = try decoder.decode(CoreHomeData.self, from: data)
                    loadedCoreData = true
                } catch {
                    print("CRITICAL ERROR: Failed to decode home_data.json from Bundle: \(error)")
                }
            }
        }
        
        // --- 2. Populate Derived Data ---
        if let core = self.coreHomeData {
            // Populate News
            if let news = core.latestNews {
                self.newsResponse = NewsResponse(latestNews: news)
            }
            
            // Populate Prediction Data
            if let species = core.speciesData {
                self.predictionData = PredictionDataWrapper(speciesData: species)
            }
        }
        
        precalculateSpotSpeciesCounts()
        // If we loaded successfully from Bundle (and not documents), save to Documents to ensure persistence for next time
        if loadedCoreData && !loadedFromDocuments {
            saveData()
        }
    }
    
    // 💡 ADD THIS NEW FUNCTION:
        private func precalculateSpotSpeciesCounts() {
            // Ensure we have spots and bird data before starting
            guard let watchlist = coreHomeData?.watchlistSpots,
                  let recommended = coreHomeData?.recommendedSpots,
                  let allSpecies = predictionData?.speciesData else { return }
            
            let allSpots = watchlist + recommended
            let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
            
            for spot in allSpots {
                guard let lat = spot.latitude, let lon = spot.longitude else { continue }
                
                let searchLoc = CLLocation(latitude: lat, longitude: lon)
                let radiusMeters = (spot.radius ?? 5.0) * 1000.0
                
                // Search through every bird in the global speciesData
                let activeBirds = allSpecies.filter { species in
                    species.sightings.contains { sighting in
                        // Logic: Is this bird sighting near the spot AND happening this week?
                        let sightingLoc = CLLocation(latitude: sighting.lat, longitude: sighting.lon)
                        let isNearby = sightingLoc.distance(from: searchLoc) <= radiusMeters
                        let isCurrentWeek = sighting.week == currentWeek
                        
                        return isNearby && isCurrentWeek
                    }
                }
                
                // Save the number of birds found for this specific spot title
                spotSpeciesCountCache[spot.title] = activeBirds.count
            }
        }
    
    // MARK: - Business Logic
    // MARK: - Business Logic

    func getDynamicMapCards() -> [MapCardType] {
        guard let core = self.coreHomeData, let dynamicCards = core.dynamicCards else { return [] }
        let allSpecies = core.speciesData ?? []
        
        return dynamicCards.compactMap { raw -> MapCardType? in
            // 💡 Use the new key names here
            guard let bName = raw.birdName,
                  let bImg = raw.birdImageName,
                  let pName = raw.placeName,
                  let pImg = raw.placeImage,
                  let mDate = raw.migrationDateRange,
                  let hDate = raw.hotspotDateRange else { return nil }
            
            var pathPoints: [CLLocationCoordinate2D] = []
            if let species = allSpecies.first(where: { $0.name == bName }) {
                pathPoints = species.sightings.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            }
            
            let migration = MigrationPrediction(
                birdName: bName, birdImageName: bImg, startLocation: raw.startLocation ?? "",
                endLocation: raw.endLocation ?? "", dateRange: mDate,
                pathCoordinates: pathPoints, currentProgress: raw.currentProgress ?? 0
            )
            
            let boundary = (raw.areaBoundary ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            let hotspots = (raw.hotspots ?? []).map { BirdHotspot(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon), birdImageName: $0.birdImageName) }
            
            let hotspot = HotspotPrediction(
                placeName: pName, placeImageName: pImg, speciesCount: raw.speciesCount ?? 0,
                distanceString: raw.distanceString ?? "", dateRange: hDate,
                areaBoundary: boundary, hotspots: hotspots, radius: raw.radius
            )
            
            return MapCardType.combined(migration, hotspot)
        }
    }

    // 💡 Private helpers make the code much easier to read
    private func convertToMigration(_ raw: DynamicCard) -> MigrationPrediction? {
        guard let bName = raw.birdName,
              let bImg = raw.birdImageName,
              let mDate = raw.migrationDateRange else { return nil }
        
        var pathPoints: [CLLocationCoordinate2D] = []
        if let species = coreHomeData?.speciesData?.first(where: { $0.name == bName }) {
            pathPoints = species.sightings.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        }
        
        return MigrationPrediction(
            birdName: bName,
            birdImageName: bImg,
            startLocation: raw.startLocation ?? "",
            endLocation: raw.endLocation ?? "",
            dateRange: mDate,
            pathCoordinates: pathPoints,
            currentProgress: raw.currentProgress ?? 0
        )
    }

    private func convertToHotspot(_ raw: DynamicCard) -> HotspotPrediction? {
        guard let pName = raw.placeName,
              let pImg = raw.placeImage,
              let hDate = raw.hotspotDateRange else { return nil }
        
        return HotspotPrediction(
            placeName: pName,
            placeImageName: pImg,
            speciesCount: raw.speciesCount ?? 0,
            distanceString: raw.distanceString ?? "",
            dateRange: hDate,
            areaBoundary: (raw.areaBoundary ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) },
            hotspots: (raw.hotspots ?? []).map { BirdHotspot(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon), birdImageName: $0.birdImageName) },
            radius: raw.radius
        )
    }
    
    fileprivate func waterfallMatchSpecies(_ allSpecies: [SpeciesData], _ isWeek: (Int, Int, Int, Int) -> Bool, _ weekRange: (start: Int, end: Int), _ lat: Double, _ degreeBuffer: Double, _ lon: Double, _ searchLoc: CLLocation, _ radiusMeters: Double, _ matchingBirds: inout [FinalPredictionResult], _ inputIndex: Int) {
        for species in allSpecies {
            
            if let matched = species.sightings.first(where: { sighting in
                
                guard isWeek(sighting.week, weekRange.start, weekRange.end, 0) else { return false }
                
                
                if abs(sighting.lat - lat) > degreeBuffer || abs(sighting.lon - lon) > degreeBuffer {
                    return false
                }
                
                let sightingLoc = CLLocation(latitude: sighting.lat, longitude: sighting.lon)
                return sightingLoc.distance(from: searchLoc) <= radiusMeters
            }) {
                matchingBirds.append(
                    FinalPredictionResult(
                        birdName: species.name,
                        imageName: species.imageName,
                        matchedInputIndex: inputIndex,
                        matchedLocation: (lat: matched.lat, lon: matched.lon),
                        spottingProbability: matched.probability ?? 75
                        
                    )
                )
            }
        }
    }
    
    func predictBirds(for input: PredictionInputData, inputIndex: Int) -> [FinalPredictionResult] {
        guard let lat = input.latitude,
              let lon = input.longitude,
              let weekRange = input.weekRange,
              let allSpecies = predictionData?.speciesData else {
            return []
        }
        
        let searchLoc = CLLocation(latitude: lat, longitude: lon)
        let radiusMeters = Double(input.areaValue) * 1000.0
        

        let degreeBuffer = radiusMeters / 111_000.0
        

        func isWeek(_ week: Int, withinStart start: Int, end: Int, tolerance: Int = 2) -> Bool {

            
            let targetStart = (start - tolerance - 1 + 52) % 52 + 1
            let targetEnd = (end + tolerance - 1 + 52) % 52 + 1

            if targetStart <= targetEnd {
                return week >= targetStart && week <= targetEnd
            } else {

                return week >= targetStart || week <= targetEnd
            }
        }
        
        var matchingBirds: [FinalPredictionResult] = []
        
        waterfallMatchSpecies(allSpecies, isWeek, weekRange, lat, degreeBuffer, lon, searchLoc, radiusMeters, &matchingBirds, inputIndex)
        
        return matchingBirds
    }
    
    func parseDateRange(_ dateString: String) -> (start: Date?, end: Date?) {
        let separators = [" – ", " - "]
        
        for separator in separators {
            let components = dateString.components(separatedBy: separator)
            if components.count == 2 {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMM ’yy"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                let start = formatter.date(from: components[0])
                let end = formatter.date(from: components[1])
                return (start, end)
            }
        }
        return (nil, nil)
    }
    
    
    func getRelevantSightings(for input: BirdDateInput) -> [Sighting] {
        guard let start = input.startDate, let end = input.endDate else { return [] }
        
        let startWeek = Calendar.current.component(.weekOfYear, from: start)
        let endWeek = Calendar.current.component(.weekOfYear, from: end)
        
        var relevantSightings: [Sighting] = []
        
        for sighting in input.species.sightings {
            var isMatch = false
            
            if startWeek <= endWeek {
                if sighting.week >= startWeek && sighting.week <= endWeek { isMatch = true }
            } else {
                if sighting.week >= startWeek || sighting.week <= endWeek { isMatch = true }
            }
            
            if !isMatch {
                let s = sighting.week
                let sStart = startWeek
                let sEnd = endWeek
                
                let distToStart = min(abs(s - sStart), 52 - abs(s - sStart))
                let distToEnd = min(abs(s - sEnd), 52 - abs(s - sEnd))
                
                if distToStart <= 2 || distToEnd <= 2 { isMatch = true }
            }
            
            if isMatch {
                relevantSightings.append(sighting)
            }
        }
        
        if startWeek > endWeek {
            relevantSightings.sort { s1, s2 in
                let w1 = s1.week < startWeek ? s1.week + 52 : s1.week
                let w2 = s2.week < startWeek ? s2.week + 52 : s2.week
                return w1 < w2
            }
        } else {
            relevantSightings.sort { $0.week < $1.week }
        }
        
        return relevantSightings
    }
    
    // 💡 ADD THIS TO HELP YOUR OUTPUT SCREEN:
        func getLivePredictions(for lat: Double, lon: Double, radiusKm: Double) -> [FinalPredictionResult] {
            guard let allSpecies = predictionData?.speciesData else { return [] }
            
            let searchLoc = CLLocation(latitude: lat, longitude: lon)
            let radiusMeters = radiusKm * 1000.0
            let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
            
            return allSpecies.compactMap { species in
                if let match = species.sightings.first(where: { s in
                    let loc = CLLocation(latitude: s.lat, longitude: s.lon)
                    return loc.distance(from: searchLoc) <= radiusMeters && s.week == currentWeek
                }) {
                    return FinalPredictionResult(
                        birdName: species.name,
                        imageName: species.imageName,
                        matchedInputIndex: 0,
                        matchedLocation: (lat: match.lat, lon: match.lon),
                        spottingProbability: match.probability ?? 70 // Use the JSON field we added
                    )
                }
                return nil
            }
        }
}
