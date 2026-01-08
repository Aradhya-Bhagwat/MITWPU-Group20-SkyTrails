//
//  MigrationCellCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit
import MapKit // CRITICAL: For map view, overlays, and annotations
import CoreLocation

// MARK: - Custom Map Overlays (The "Stickers")

// Tag for the Full Predicted Path (Pale Blue)
class PredictedPathPolyline: MKPolyline {}

// Tag for the Progress Completed Path (Dark Blue)
class ProgressPathPolyline: MKPolyline {}

// Tag for the Current Location Pin (We will use this later)
class CurrentLocationAnnotation: MKPointAnnotation {}

extension Array where Element == CLLocationCoordinate2D {
    
    func interpolatedProgress(at percentage: Double) -> (progressCoords: [CLLocationCoordinate2D], currentCoord: CLLocationCoordinate2D) {
        
        // Handle edge cases where path has less than 2 points
        guard self.count > 1 else {
            if let singleCoord = self.first {
                return ([singleCoord], singleCoord)
            }
            return ([], CLLocationCoordinate2D())
        }
        
        // Ensure percentage is bounded between 0 and 1
        let boundedPercentage = Swift.min(1.0, Swift.max(0.0, percentage))
        
        let totalPathLength = self.totalLength()
        let targetDistance = boundedPercentage * totalPathLength
        
        var currentDistance: Double = 0
        var segmentCoords: [CLLocationCoordinate2D] = [self.first!] // Start with the first point
        
        // If progress is 100%, return the full path
        if boundedPercentage >= 1.0 {
            return (self, self.last!)
        }
        
        // Iterate through all segments (pairs of coordinates)
        for i in 0..<(self.count - 1) {
            let startCoord = self[i]
            let endCoord = self[i+1]
            
            // Calculate the length of the current segment using CLLocations
            let segmentLength = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
                                          .distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))
            
            // Check if the target distance falls within this segment
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
    
    // 1. Map View
    @IBOutlet private weak var cardContainerView: UIView!
    @IBOutlet private weak var mapView: MKMapView!
    
    // 2. Overlay View Elements (The bottom white card area)
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
        
        // 1. Force the Width to match the Layout's requirement (Screen Width - Margins)
        // This ensures the cell stretches horizontally as requested.
        var targetFrame = layoutAttributes.frame
        targetFrame.size.width = layoutAttributes.frame.width
        
        let targetSize = CGSize(width: targetFrame.width, height: UIView.layoutFittingCompressedSize.height)
        
        // 2. Ensure layout is up-to-date before calculating size
        self.layoutIfNeeded()
        
        let autoLayoutSize = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        // 3. Update the attributes with the calculated height
        var newAttributes = layoutAttributes.copy() as! UICollectionViewLayoutAttributes
        newAttributes.frame = CGRect(origin: targetFrame.origin, size: CGSize(width: targetFrame.width, height: autoLayoutSize.height))
        
        return newAttributes
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Clear all dynamic data when the cell is reused
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
        
        // 1. Shadow Path Update
        // Always update the shadow path when layout changes to maintain performance.
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        
        // 2. Proportional Font Scaling
        // Your Ratio: 17/200 = 0.085. Let's apply it to your current base sizes.
        let currentWidth = self.bounds.width
        let baseWidth: CGFloat = 700.0
        let titleRatio: CGFloat = 20.0 / baseWidth // Scaling based on your 20pt starting point
        let detailRatio: CGFloat = 12.0 / baseWidth // Scaling based on your 12pt starting point
        
        // Apply calculated sizes
        birdNameLabel.font = UIFont.systemFont(ofSize: currentWidth * titleRatio, weight: .semibold)
        
        let detailSize = currentWidth * detailRatio
        startLocationLabel.font = UIFont.systemFont(ofSize: detailSize, weight: .regular)
        endLocationLabel.font = UIFont.systemFont(ofSize: detailSize, weight: .regular)
        startDateLabel.font = UIFont.systemFont(ofSize: detailSize, weight: .regular)
        endDateLabel.font = UIFont.systemFont(ofSize: detailSize, weight: .regular)
    }
    func configure(with prediction: MigrationPrediction) {
        
        birdNameLabel.text = prediction.birdName
        birdNameLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        startLocationLabel.text = prediction.startLocation
        endLocationLabel.text = prediction.endLocation
        
        let dateRangePrefixLength = prediction.dateRange.count / 2
        startDateLabel.text = prediction.dateRange.prefix(dateRangePrefixLength).trimmingCharacters(in: .whitespacesAndNewlines)
        endDateLabel.text = prediction.dateRange.suffix(dateRangePrefixLength).trimmingCharacters(in: .whitespacesAndNewlines)
        
        progressView.progress = prediction.currentProgress
        birdImageView.image = UIImage(named: prediction.birdImageName)
        
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        let fullCoordinates = prediction.pathCoordinates // The full list of coordinates
        let totalPoints = fullCoordinates.count
        
        var annotationsToAdd: [MKAnnotation] = []
        
        
        var progressCoordinates: [CLLocationCoordinate2D] = []
        var currentLocation: CLLocationCoordinate2D?
        
        if totalPoints > 1 {
            // Convert Float progress to Double
            let progressPercentage = Double(prediction.currentProgress)
            let result = fullCoordinates.interpolatedProgress(at: progressPercentage)
            
            progressCoordinates = result.progressCoords
            currentLocation = result.currentCoord
            
        } else if totalPoints == 1 {
            // Handle case where path is just a single point
            currentLocation = fullCoordinates.first
            progressCoordinates = fullCoordinates
        }
        
        let predictedPath = PredictedPathPolyline(coordinates: fullCoordinates, count: totalPoints)
        mapView.addOverlay(predictedPath)

        // B. Progress Path (Default Blue, Traveled Segment) - Draw this SECOND (top layer)
        if progressCoordinates.count >= 1 {
            let progressPath = ProgressPathPolyline(coordinates: progressCoordinates, count: progressCoordinates.count)
            mapView.addOverlay(progressPath)
        }
        
        // Start/End Annotations
        if let startCoord = fullCoordinates.first,
           let endCoord = fullCoordinates.last {
            
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = startCoord
            startAnnotation.title = prediction.startLocation
            annotationsToAdd.append(startAnnotation)
            
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = endCoord
            endAnnotation.title = prediction.endLocation
            annotationsToAdd.append(endAnnotation)
        }

        // Current Location Annotation (Pin)
        if let currentCoord = currentLocation {
            // We use the custom class here to style the pin uniquely (e.g., orange color)
            let currentAnnotation = CurrentLocationAnnotation()
            currentAnnotation.coordinate = currentCoord
            currentAnnotation.title = "Current Predicted Location"
            annotationsToAdd.append(currentAnnotation)
        }
        
        mapView.addAnnotations(annotationsToAdd)
        
        let fullPathLine = MKPolyline(coordinates: fullCoordinates, count: fullCoordinates.count)
        zoomToFitOverlays(for: fullPathLine)
    }
        private func zoomToFitOverlays(for pathLine: MKPolyline) {
                let rect = pathLine.boundingMapRect
                let edgePadding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
                mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
            }
}

extension MigrationCellCollectionViewCell: MKMapViewDelegate {
    
    // Defines how to render the path line (Coloring Logic)
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 4
            renderer.lineCap = .round
            
            if polyline is PredictedPathPolyline {
                // Pale Blue/Faded Color for the full predicted route
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.35)
            } else if polyline is ProgressPathPolyline {
                // Default/Darker Blue for the traveled segment (on top)
                renderer.strokeColor = UIColor.systemBlue
            }
            return renderer
        }
        
        // Fallback for other overlays
        return MKOverlayRenderer(overlay: overlay)
    }
    
    // Defines how to display annotations (Pins)
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is CurrentLocationAnnotation {
            let identifier = "CurrentPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.markerTintColor = .systemOrange // 👈 Distinct color (e.g., Orange)
    
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
