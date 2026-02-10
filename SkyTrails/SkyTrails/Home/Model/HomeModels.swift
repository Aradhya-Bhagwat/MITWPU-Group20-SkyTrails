//
//  HomeModels.swift
//  SkyTrails
//
//  Simplified - UI models only
//

import Foundation
import CoreLocation

// MARK: - UI Models (Non-SwiftData)

// Keep these for UI compatibility
struct BirdCategory: Codable, Hashable {
    let icon: String
    let title: String
}

// Legacy support for prediction screen
struct PredictionInputData {
    var id: UUID = UUID()
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var startDate: Date? = Date()
    var endDate: Date? = Date()
    var areaValue: Int = 2
    
    var weekRange: (start: Int, end: Int)? {
        guard let start = startDate, let end = endDate else { return nil }
        
        let startWeek = start.weekOfYear
        let endWeek = end.weekOfYear
        
        if startWeek > endWeek {
            return (start: startWeek, end: endWeek + 52)
        }
        return (start: startWeek, end: endWeek)
    }
}

struct FinalPredictionResult: Hashable {
    let birdName: String
    let imageName: String
    let matchedInputIndex: Int
    let matchedLocation: (lat: Double, lon: Double)
    let spottingProbability: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(birdName)
    }
    
    static func == (lhs: FinalPredictionResult, rhs: FinalPredictionResult) -> Bool {
        return lhs.birdName == rhs.birdName
    }
}

// MARK: - Extensions

extension Date {
    var weekOfYear: Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: self)
    }
}