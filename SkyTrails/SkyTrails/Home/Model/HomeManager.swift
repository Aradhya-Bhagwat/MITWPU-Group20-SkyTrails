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
        
        // If we loaded successfully from Bundle (and not documents), save to Documents to ensure persistence for next time
        if loadedCoreData && !loadedFromDocuments {
            saveData()
        }
    }
    
    // MARK: - Business Logic
    
	func getDynamicMapCards() -> [MapCardType] {
		guard let dynamicCards = coreHomeData?.dynamicCards else { return [] }
		
		return dynamicCards.compactMap { rawCard -> MapCardType? in
			let toCoords: ([RawCoordinate]) -> [CLLocationCoordinate2D] = {
				$0.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
			}
			
			switch rawCard.cardType {
				case "migration":
					guard let name = rawCard.birdName,
						  let image = rawCard.birdImageName,
						  let start = rawCard.startLocation,
						  let end = rawCard.endLocation,
						  let date = rawCard.dateRange,
						  let progress = rawCard.currentProgress,
						  let rawPoints = rawCard.pathPoints else { return nil }
					
					return .migration(MigrationPrediction(
						birdName: name,
						birdImageName: image,
						startLocation: start,
						endLocation: end,
						dateRange: date,
						pathCoordinates: toCoords(rawPoints),
						currentProgress: progress
					))
					
				case "hotspot":
					guard let name = rawCard.placeName,
						  let image = rawCard.placeImage,
						  let count = rawCard.speciesCount,
						  let distance = rawCard.distanceString,
						  let date = rawCard.dateRange,
						  let rawBoundary = rawCard.areaBoundary,
						  let rawHotspots = rawCard.hotspots else { return nil }
					
					return .hotspot(HotspotPrediction(
						placeName: name,
						placeImageName: image,
						speciesCount: count,
						distanceString: distance,
						dateRange: date,
						areaBoundary: toCoords(rawBoundary),
						hotspots: rawHotspots.map { BirdHotspot(
							coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon),
							birdImageName: $0.birdImageName
						)},
						radius: rawCard.radius
					))
					
				default:
					return nil
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
        
        let radiusKM = Double(input.areaValue)
        let searchLoc = CLLocation(latitude: lat, longitude: lon)
        
        var matchingBirds: [FinalPredictionResult] = []
        
        for species in allSpecies {
            
            var speciesFoundForThisInput = false
            
            for sighting in species.sightings {
                
                let sightingWeek = sighting.week
                var isWeekMatch = false
                
                if weekRange.start <= weekRange.end {
                    isWeekMatch = (sightingWeek >= weekRange.start) && (sightingWeek <= weekRange.end)
                } else {
                    let checkWeek = sightingWeek > weekRange.start ? sightingWeek : sightingWeek + 52
                    isWeekMatch = (checkWeek >= weekRange.start) && (checkWeek <= weekRange.end)
                }
                
                if !isWeekMatch {
                    let startBound = weekRange.start - 2
                    let endBound = weekRange.end + 2
                    isWeekMatch = (sightingWeek >= startBound && sightingWeek <= endBound)
                }
                
                if !isWeekMatch { continue }
                
                let sightingLoc = CLLocation(latitude: sighting.lat, longitude: sighting.lon)
                let distanceKM = sightingLoc.distance(from: searchLoc) / 1000.0
                
                if distanceKM <= radiusKM {
                    matchingBirds.append(
                        FinalPredictionResult(
                            birdName: species.name,
                            imageName: species.imageName,
                            matchedInputIndex: inputIndex,
                            matchedLocation: (lat: sighting.lat, lon: sighting.lon)
                        )
                    )
                    speciesFoundForThisInput = true
                    break
                }
            }
            if speciesFoundForThisInput { continue }
        }
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
    
    func getPredictions(for spot: PopularSpot) -> [FinalPredictionResult] {
        return (spot.birds ?? []).map { bird in
            return FinalPredictionResult(
                birdName: bird.name,
                imageName: bird.imageName,
                matchedInputIndex: 0, // All match this single input
                matchedLocation: (lat: bird.lat, lon: bird.lon)
            )
        }
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
}
