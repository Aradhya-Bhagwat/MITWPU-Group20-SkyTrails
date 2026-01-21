//
//  MapOverlays.swift
//  SkyTrails
//
//  Created by SDC-USER on 13/01/26.
//

import MapKit

class PredictedPathPolyline: MKPolyline {}
class ProgressPathPolyline: MKPolyline {}
class CurrentLocationAnnotation: MKPointAnnotation {}
class HotspotBoundaryPolygon: MKPolygon {}
class HotspotBirdAnnotation: MKPointAnnotation {
    var imageName: String?
}

extension Array where Element == CLLocationCoordinate2D {
    func interpolatedProgress(at percentage: Double) -> (progressCoords: [CLLocationCoordinate2D], currentCoord: CLLocationCoordinate2D) {
        guard self.count > 1 else {
            return (self, self.first ?? CLLocationCoordinate2D())
        }
        
        let bounded = Swift.min(1.0, Swift.max(0.0, percentage))
        let totalPoints = Int(Double(self.count - 1) * bounded)
        let progressCoords = Array(self.prefix(totalPoints + 1))
        return (progressCoords, progressCoords.last ?? self[0])
    }
}
