import Foundation
import CoreLocation
import SwiftData

final class RuleMatchingService {
    
    func matches(bird: Bird, ruleParams: RuleParameters, location: CLLocationCoordinate2D?, observationDate: Date?) -> Bool {
        switch ruleParams {
        case .speciesFamily(let params):
            return bird.shape_id == params.shapeId
            
        case .location(let params):
            guard let birdLocation = location else { return false }
            let watchlistLocation = CLLocation(latitude: params.lat, longitude: params.lon)
            let birdCLLocation = CLLocation(latitude: birdLocation.latitude, longitude: birdLocation.longitude)
            let distance = watchlistLocation.distance(from: birdCLLocation) / 1000.0
            return distance <= params.radiusKm
            
        case .dateRange(let params):
            guard let birdDate = observationDate else { return false }
            return birdDate >= params.startDate && birdDate <= params.endDate
            
        case .migration(let params):
            return bird.migration_strategy == params.patternKey
        }
    }
    
    func matchesAnyRule(bird: Bird, rules: [WatchlistRule], location: CLLocationCoordinate2D?, observationDate: Date?) -> Bool {
        for rule in rules {
            guard let ruleParams = RuleParameters.from(rule: rule) else { continue }
            if matches(bird: bird, ruleParams: ruleParams, location: location, observationDate: observationDate) {
                return true
            }
        }
        return false
    }
}