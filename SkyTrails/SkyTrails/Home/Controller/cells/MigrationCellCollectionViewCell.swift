//
//  MigrationCellCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit
import MapKit
import CoreLocation

// MARK: - Custom Map Overlays (The "Stickers")

extension Array where Element == CLLocationCoordinate2D {
    
    func interpolatedProgress(at percentage: Double) -> (progressCoords: [CLLocationCoordinate2D], currentCoord: CLLocationCoordinate2D) {
        
        guard self.count > 1 else {
            if let singleCoord = self.first {
                return ([singleCoord], singleCoord)
            }
            return ([], CLLocationCoordinate2D())
        }
        let boundedPercentage = Swift.min(1.0, Swift.max(0.0, percentage))
        
        let totalPathLength = self.totalLength()
        let targetDistance = boundedPercentage * totalPathLength
        
        var currentDistance: Double = 0
        var segmentCoords: [CLLocationCoordinate2D] = [self.first!]
        
        if boundedPercentage >= 1.0 {
            return (self, self.last!)
        }
        
        for i in 0..<(self.count - 1) {
            let startCoord = self[i]
            let endCoord = self[i+1]
            
            let segmentLength = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
                                          .distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))
        
            if (currentDistance + segmentLength) >= targetDistance {
                let remainingDistanceInSegment = targetDistance - currentDistance
                let ratio = remainingDistanceInSegment / segmentLength
                let interpolatedLatitude = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * ratio
                let interpolatedLongitude = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * ratio
                
                let interpolatedCoord = CLLocationCoordinate2D(latitude: interpolatedLatitude, longitude: interpolatedLongitude)
                
                segmentCoords.append(interpolatedCoord)
  
                return (segmentCoords, interpolatedCoord)
            }

            currentDistance += segmentLength
            segmentCoords.append(endCoord)
        }

        return (self, self.last ?? CLLocationCoordinate2D())
    }
    
    private func totalLength() -> Double {
        guard self.count > 1 else { return 0 }
        var totalLength: Double = 0
        for i in 0..<(self.count - 1) {
            let coord1 = self[i]
            let coord2 = self[i+1]
            let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
            totalLength += location1.distance(from: location2)
        }
        return totalLength
    }
}

class MigrationCellCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "MigrationCellCollectionViewCell"
    
    @IBOutlet private weak var cardContainerView: UIView!
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var overlayContentView: UIView!
    @IBOutlet private weak var birdImageView: UIImageView!
    @IBOutlet private weak var birdNameLabel: UILabel!
    @IBOutlet private weak var startLocationLabel: UILabel!
    @IBOutlet private weak var endLocationLabel: UILabel!
    @IBOutlet private weak var startDateLabel: UILabel!
    @IBOutlet private weak var endDateLabel: UILabel!
    @IBOutlet private weak var progressView: CurvedProgressView!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
                
            cardContainerView?.layer.cornerRadius = 16
            cardContainerView?.layer.masksToBounds = true
        
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.1
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 8
            layer.masksToBounds = false
        
        mapView?.layer.cornerRadius = 12
        mapView?.layer.masksToBounds = true
        mapView?.delegate = self
        mapView?.isZoomEnabled = false
        mapView?.isScrollEnabled = false
        
        birdImageView?.layer.cornerRadius = 8 // Example
        birdImageView?.layer.masksToBounds = true
        birdImageView?.contentMode = .scaleAspectFill
        
    }
    
    // MARK: - Self Sizing & Layout Fixes
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
       
        var targetFrame = layoutAttributes.frame
        targetFrame.size.width = layoutAttributes.frame.width
        
        let targetSize = CGSize(width: targetFrame.width, height: UIView.layoutFittingCompressedSize.height)
        
        
        self.layoutIfNeeded()
        
        let autoLayoutSize = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let newAttributes = layoutAttributes.copy() as! UICollectionViewLayoutAttributes
        newAttributes.frame = CGRect(origin: targetFrame.origin, size: CGSize(width: targetFrame.width, height: autoLayoutSize.height))
        
        return newAttributes
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        birdNameLabel.text = nil
        startLocationLabel.text = nil
        endLocationLabel.text = nil
        startDateLabel.text = nil
        endDateLabel.text = nil
        progressView.progress = 0
        birdImageView.image = nil
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        
        let currentWidth = self.bounds.width
        let baseWidth: CGFloat = 361.0
        let titleRatio: CGFloat = 20.0 / baseWidth
        let detailRatio: CGFloat = 12.0 / baseWidth
        let calculatedTitleSize = currentWidth * titleRatio
        birdNameLabel.font = UIFont.systemFont(
            ofSize: min(calculatedTitleSize, 30.0),
            weight: .semibold
        )
        let calculatedDetailSize = currentWidth * detailRatio
        let cappedDetailSize = min(calculatedDetailSize, 18.0)
        
        let detailFont = UIFont.systemFont(ofSize: cappedDetailSize, weight: .regular)
        
        startLocationLabel.font = detailFont
        endLocationLabel.font = detailFont
        startDateLabel.font = detailFont
        endDateLabel.font = detailFont
    }
    func configure(with prediction: MigrationPrediction) {
        birdNameLabel.text = prediction.birdName
        startLocationLabel.text = prediction.startLocation
        endLocationLabel.text = prediction.endLocation
        
        // 1. FIX: Flexible Date Parsing
        // This looks for common separators (long dash, short dash, or multiple spaces)
        let separators = [" – ", " - ", "   "]
        var dateComponents: [String] = []
        
        for sep in separators {
            let parts = prediction.dateRange.components(separatedBy: sep)
            if parts.count >= 2 {
                dateComponents = parts.map { $0.trimmingCharacters(in: .whitespaces) }
                break
            }
        }
        
        if dateComponents.count >= 2 {
            startDateLabel.text = dateComponents[0]
            endDateLabel.text = dateComponents[1]
        }

        progressView.progress = prediction.currentProgress
        birdImageView.image = UIImage(named: prediction.birdImageName)
        
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard let species = PredictionEngine.shared.allSpecies.first(where: { $0.name == prediction.birdName }) else { return }
        
        let fullCoordinates = species.sightings.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        guard !fullCoordinates.isEmpty else { return }
        
        var annotationsToAdd: [MKAnnotation] = []

        // 2. FIX: Explicitly add Start and End Pins
        if let startCoord = fullCoordinates.first {
            let startPin = MKPointAnnotation()
            startPin.coordinate = startCoord
            startPin.title = prediction.startLocation
            annotationsToAdd.append(startPin)
        }
        
        if let endCoord = fullCoordinates.last {
            let endPin = MKPointAnnotation()
            endPin.coordinate = endCoord
            endPin.title = prediction.endLocation
            annotationsToAdd.append(endPin)
        }

        // 3. Add Path and Progress
        if fullCoordinates.count > 1 {
            let result = fullCoordinates.interpolatedProgress(at: Double(prediction.currentProgress))
            
            // Add blue progress line
            let progressPath = ProgressPathPolyline(coordinates: result.progressCoords, count: result.progressCoords.count)
            mapView.addOverlay(progressPath)
            
            // Add Orange Current Location Pin
            let currentAnnotation = CurrentLocationAnnotation()
            currentAnnotation.coordinate = result.currentCoord
            currentAnnotation.title = "Currently here"
            annotationsToAdd.append(currentAnnotation)
        }
        
        // Add gray background predicted path
        let predictedPath = PredictedPathPolyline(coordinates: fullCoordinates, count: fullCoordinates.count)
        mapView.addOverlay(predictedPath)
        
        // Add all pins to the map
        mapView.addAnnotations(annotationsToAdd)
        
        // 4. Force visibility of all pins (Safety)
        zoomToFitOverlays(for: predictedPath)
    }
        private func zoomToFitOverlays(for pathLine: MKPolyline) {
                let rect = pathLine.boundingMapRect
                let edgePadding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
                mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
            }
}

extension MigrationCellCollectionViewCell: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 4
            renderer.lineCap = .round
            
            if polyline is PredictedPathPolyline {
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.35)
            } else if polyline is ProgressPathPolyline {
                renderer.strokeColor = UIColor.systemBlue
            }
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is CurrentLocationAnnotation {
            let identifier = "CurrentPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.markerTintColor = .systemOrange
    
            } else {
                annotationView?.annotation = annotation
            }
            return annotationView
        }

        guard annotation is MKPointAnnotation else { return nil }
        
        let identifier = "MigrationPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            annotationView?.markerTintColor = .systemRed
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
}
