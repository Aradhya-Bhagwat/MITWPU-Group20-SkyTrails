//
//  HotspotCellCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit
import MapKit
import CoreLocation

class HotspotBoundaryPolygon: MKPolygon {}

// Tag for the individual bird sighting pins
class HotspotBirdAnnotation: MKPointAnnotation {
    var imageName: String?
}

class HotspotCellCollectionViewCell: UICollectionViewCell, MKMapViewDelegate {
    
    static let identifier = "HotspotCellCollectionViewCell"
    
    @IBOutlet weak var containerview: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var PlaceImage: UIImageView!
    @IBOutlet weak var overlayContentview: UIView!
    @IBOutlet weak var PlaceName: UILabel!
    @IBOutlet weak var NoSpecies: UILabel!
    @IBOutlet weak var Distance: UILabel!
    @IBOutlet weak var Date: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    // Inside HotspotCellCollectionViewCell.swift
    func configure(with prediction: HotspotPrediction) {
            // This is where all the data is set and map drawing is triggered
            
            // 1. UI Setup
        containerview.layer.cornerRadius = 16
        containerview.layer.masksToBounds = true
        
            PlaceName.text = prediction.placeName
            PlaceName.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        
            NoSpecies.text = "\(prediction.speciesCount) Species spotted"
            Distance.text = prediction.distanceString
            Date.text = prediction.dateRange
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.masksToBounds = false
        
        
            PlaceImage.image = UIImage(named: prediction.placeImageName)
            PlaceImage.layer.cornerRadius = 8
            PlaceImage.layer.masksToBounds = true
            PlaceImage.contentMode = .scaleAspectFill
            // The birdImage needs to be set up here, but that data isn't in HotspotPrediction
            // (You might need to adjust your data model or skip it for now, as per the target image).
            
            // 2. Map Setup
            mapView.delegate = self
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            mapView.layer.cornerRadius = 12
            mapView.layer.masksToBounds = true
            mapView.delegate = self
            mapView.isZoomEnabled = false
            mapView.isScrollEnabled = false
            
            setupHotspotMap(with: prediction)
        }

    func setupHotspotMap(with prediction: HotspotPrediction) {
        
        var annotationsToAdd: [MKAnnotation] = []
        
        // 1. Draw Area Boundary (The Polygon)
        if !prediction.areaBoundary.isEmpty {
            let smoothedBoundary = prediction.areaBoundary.generateSmoothedPath()
            let polygon = HotspotBoundaryPolygon(coordinates: prediction.areaBoundary,
                                                 count: prediction.areaBoundary.count)
            mapView.addOverlay(polygon)
        }
        
        // 2. Add Hotspot Pins (Custom Icons)
        for hotspot in prediction.hotspots {
            let annotation = HotspotBirdAnnotation()
            annotation.coordinate = hotspot.coordinate
            // The custom pin icon will be loaded using this image name in the delegate method
            annotation.imageName = hotspot.birdImageName
            annotation.title = "Bird Sighting"
            annotationsToAdd.append(annotation)
        }
        
        mapView.addAnnotations(annotationsToAdd)

        // 3. Zoom to Fit the Polygon Area
        if let firstCoord = prediction.areaBoundary.first {
            let zoomPolyline = MKPolyline(coordinates: prediction.areaBoundary,
                                          count: prediction.areaBoundary.count)
            zoomToFitOverlays(for: zoomPolyline)
        }
    }

    private func zoomToFitOverlays(for pathLine: MKPolyline) {
        let rect = pathLine.boundingMapRect
        let edgePadding = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
    }
}
// Inside HotspotCellCollectionViewCell.swift

// MARK: - Map Delegate (Styling Hotspots)

extension HotspotCellCollectionViewCell {
    
    // Renderer for Polygons
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if let polygon = overlay as? HotspotBoundaryPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            // Light Blue Fill, Darker Blue Stroke (Matching visual design)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.4)
            renderer.lineWidth = 2
            return renderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
    
    // View for Annotations (Custom Image Icons)
    // In HotspotCellCollectionViewCell.swift -> extension HotspotCellCollectionViewCell
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        guard let hotspotAnnotation = annotation as? HotspotBirdAnnotation else {
            return nil
        }
        
        let identifier = "HotspotBirdPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        // --- 1. Setup Annotation View ---
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: hotspotAnnotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = false // Prevent callout conflict with clipping
        } else {
            annotationView?.annotation = annotation
        }
        
        // --- 2. Draw and Shape the Custom Pin Image ---
        if let imageName = hotspotAnnotation.imageName,
           let birdImage = UIImage(named: imageName) {
            
            let outerPinSize: CGFloat = 40.0 // Width/Height of the outer circle
            let innerImageSize: CGFloat = 32.0 // Size of the bird image inside the border
            let pinHeight: CGFloat = 50.0
            let tailBaseMargin: CGFloat = 12.0// Total height of the image (circle + tail)
            
            let pinBaseSize = CGSize(width: outerPinSize, height: pinHeight)
            let renderer = UIGraphicsImageRenderer(size: pinBaseSize)
            
            
            let finalPinImage = renderer.image { context in
                let cgContext = context.cgContext
                let pinColor = UIColor(red: 12/255, green: 70/255, blue: 156/255, alpha: 0.9).cgColor// Use dark blue for pin body
                
                // --- A. DRAW THE PIN BODY (Circle and Tail) ---
                
                // Draw the tail part (a triangle)
                cgContext.beginPath()
                cgContext.move(to: CGPoint(x: pinBaseSize.width / 2 , y: pinHeight)) // Tip of the pin
                cgContext.addLine(to: CGPoint(x: 12, y: outerPinSize - 4)) // Left side of circle bottom
                cgContext.addLine(to: CGPoint(x: pinBaseSize.width - 12, y: outerPinSize - 4)) // Right side of circle bottom
                cgContext.closePath()
                cgContext.setFillColor(pinColor)
                cgContext.fillPath()
                
                // Draw the main circle part of the pin (the base)
                let outerCircleRect = CGRect(x: 0, y: 0, width: outerPinSize, height: outerPinSize)
                cgContext.addEllipse(in: outerCircleRect)
                cgContext.setFillColor(pinColor)
                cgContext.fillPath()
                
                // --- B. DRAW WHITE BORDER ---
                // Draw a white circle slightly inside the dark blue base circle
                let whiteBorderRect = CGRect(x: 2, y: 2, width: outerPinSize - 4, height: outerPinSize - 4)
                cgContext.addEllipse(in: whiteBorderRect)
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fillPath()
                
                // --- C. DRAW BIRD IMAGE (Clips and centers the bird) ---
                // Define where the bird image will sit (centered in the white border)
                let imageRect = CGRect(x: (outerPinSize - innerImageSize) / 2,
                                       y: (outerPinSize - innerImageSize) / 2,
                                       width: innerImageSize,
                                       height: innerImageSize)
                
                // Clip the context to the circular area for the bird image
                cgContext.addEllipse(in: imageRect)
                cgContext.clip()
                
                // Draw the bird image inside the clipped circular area
                birdImage.draw(in: imageRect)
            }
            
            annotationView?.image = finalPinImage
            
            // 2b. Set the anchor point (Crucial: the bottom tip must align with the coordinate)
            // Set centerOffset Y to half the image height (50/2) plus 10 points to push the tip down.
            annotationView?.centerOffset = CGPoint(x: 0, y: pinHeight / 50 - 4)
            
            // Remove circular styling (the image is now the pin shape)
            annotationView?.layer.cornerRadius = 0
            annotationView?.layer.masksToBounds = false
        }
        
        return annotationView
    }
}
