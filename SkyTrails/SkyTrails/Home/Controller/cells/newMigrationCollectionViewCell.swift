//
//  newMigrationCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 14/01/26.
//

import UIKit
import MapKit
import CoreLocation



class newMigrationCollectionViewCell: UICollectionViewCell, MKMapViewDelegate {
    
    static let identifier = "newMigrationCollectionViewCell"

    @IBOutlet weak var cardContainerView: UIView!
        @IBOutlet weak var birdImageView: UIImageView!
        @IBOutlet weak var birdNameLabel: UILabel!
        @IBOutlet weak var startLocationLabel: UILabel!
        @IBOutlet weak var endLocationLabel: UILabel!
        @IBOutlet weak var startDateLabel: UILabel!
        @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
       @IBOutlet weak var overlayContentView1: UIView!
    @IBOutlet weak var progressView: CurvedProgressView!
    
    @IBOutlet weak var PlaceName: UILabel!
        @IBOutlet weak var NoSpecies: UILabel!
        @IBOutlet weak var Distance: UILabel!
        @IBOutlet weak var DateLabel: UILabel!
        @IBOutlet weak var PlaceImage: UIImageView!
    @IBOutlet weak var overlayContentView2: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        // Initialization code
    }
    private func setupUI() {
            contentView.backgroundColor = .clear
            
            // Combined Stylings
            cardContainerView?.layer.cornerRadius = 16
            cardContainerView?.layer.masksToBounds = true
            
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.1
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 8
            layer.masksToBounds = false
            
            // Image Stylings
            [birdImageView, PlaceImage].forEach { imgView in
                imgView?.layer.cornerRadius = 8
                imgView?.layer.masksToBounds = true
                imgView?.contentMode = .scaleAspectFill
            }
            
            // Map Placeholder Styling
            mapView?.layer.cornerRadius = 12
            mapView?.layer.masksToBounds = true
            mapView?.isZoomEnabled = false
            mapView?.isScrollEnabled = false
            // Note: Delegate will be set when you implement the map logic later
        }

        // MARK: - Dynamic Font Scaling
    override func layoutSubviews() {
            super.layoutSubviews()
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
            
            let currentWidth = self.bounds.width
            let baseWidth: CGFloat = 361.0
            
            let titleRatio: CGFloat = 20.0 / baseWidth
            let calculatedTitleSize = min(currentWidth * titleRatio, 30.0)
            let titleFont = UIFont.systemFont(ofSize: calculatedTitleSize, weight: .semibold)
            
            birdNameLabel.font = titleFont
            PlaceName.font = titleFont
            
            let detailRatio: CGFloat = 12.0 / baseWidth
            let calculatedDetailSize = min(currentWidth * detailRatio, 18.0)
            let detailFont = UIFont.systemFont(ofSize: calculatedDetailSize, weight: .regular)
            
            [startLocationLabel, endLocationLabel, startDateLabel, endDateLabel,
             NoSpecies, Distance, DateLabel].forEach { label in
                label?.font = detailFont
            }
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            birdImageView.image = nil
            PlaceImage.image = nil
            birdNameLabel.text = nil
            PlaceName.text = nil
            progressView.progress = 0
            // Clean map markers without complex logic
            mapView.removeAnnotations(mapView.annotations)
            mapView.removeOverlays(mapView.overlays)
        }

        func configure(migration: MigrationPrediction, hotspot: HotspotPrediction) {
            // 1. Set Migration UI
            birdNameLabel.text = migration.birdName
            birdImageView.image = UIImage(named: migration.birdImageName)
            startLocationLabel.text = migration.startLocation
            endLocationLabel.text = migration.endLocation
            progressView.progress = migration.currentProgress
            
            let separators = [" – ", " - ", "   "]
            var dateComponents: [String] = []
            for sep in separators {
                let parts = migration.dateRange.components(separatedBy: sep)
                if parts.count >= 2 {
                    dateComponents = parts.map { $0.trimmingCharacters(in: .whitespaces) }
                    break
                }
            }
            if dateComponents.count >= 2 {
                startDateLabel.text = dateComponents[0]
                endDateLabel.text = dateComponents[1]
            }
            
            // 2. Set Hotspot UI
            PlaceName.text = hotspot.placeName
            NoSpecies.text = "\(hotspot.speciesCount) Species spotted"
            Distance.text = hotspot.distanceString
            DateLabel.text = hotspot.dateRange
            PlaceImage.image = UIImage(named: hotspot.placeImageName)
            
            // 3. Simple Map Centering (No overlays/pins)
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            setupMap(migration: migration, hotspot: hotspot)
        }
    
    private func setupMap(migration: MigrationPrediction, hotspot: HotspotPrediction) {
        mapView.delegate = self
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        var allAnnotations: [MKAnnotation] = []

        // 1. Migration Pins
        if let start = migration.pathCoordinates.first {
            let pin = MKPointAnnotation()
            pin.coordinate = start
            pin.title = "Start: \(migration.startLocation)"
            allAnnotations.append(pin)
        }
        
        if let end = migration.pathCoordinates.last {
            let pin = MKPointAnnotation()
            pin.coordinate = end
            pin.title = "End: \(migration.endLocation)"
            allAnnotations.append(pin)
        }

        // 2. Current Location Pin
        if migration.pathCoordinates.count > 1 {
            let result = migration.pathCoordinates.interpolatedProgress(at: Double(migration.currentProgress))
            let currentAnnotation = CurrentLocationAnnotation()
            currentAnnotation.coordinate = result.currentCoord
            currentAnnotation.title = "Current Position"
            allAnnotations.append(currentAnnotation)
        }

        // 3. Hotspot Pins (Bird Sightings)
        for birdSpot in hotspot.hotspots {
            let annotation = HotspotBirdAnnotation()
            annotation.coordinate = birdSpot.coordinate
            annotation.imageName = birdSpot.birdImageName
            annotation.title = "Sighting"
            allAnnotations.append(annotation)
        }

        mapView.addAnnotations(allAnnotations)
        zoomToFitPins(allAnnotations)
    }

    private func zoomToFitPins(_ annotations: [MKAnnotation]) {
        guard !annotations.isEmpty else { return }
        
        var zoomRect = MKMapRect.null
        for annotation in annotations {
            let point = MKMapPoint(annotation.coordinate)
            let rect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            zoomRect = zoomRect.union(rect)
        }
        
        let padding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
        mapView.setVisibleMapRect(zoomRect, edgePadding: padding, animated: false)
    }
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
        } else if let polygon = overlay as? HotspotBoundaryPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.4)
            renderer.lineWidth = 2
            return renderer
        } else if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5)
            renderer.lineWidth = 1
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
        } else if let hotspotAnnotation = annotation as? HotspotBirdAnnotation {
             let identifier = "HotspotBirdPin"
             var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
             if annotationView == nil {
                 annotationView = MKMarkerAnnotationView(annotation: hotspotAnnotation, reuseIdentifier: identifier)
                 annotationView?.canShowCallout = true
             } else {
                 annotationView?.annotation = annotation
             }
             annotationView?.displayPriority = .required
             annotationView?.markerTintColor = .systemTeal
             annotationView?.glyphImage = UIImage(systemName: "bird.fill")
             return annotationView
        } else if annotation is MKPointAnnotation {
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
        return nil
    }
}
