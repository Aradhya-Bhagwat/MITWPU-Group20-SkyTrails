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
     
    }
 
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        
        let currentWidth = self.bounds.width
        let baseWidth: CGFloat = 361.0

        let titleRatio: CGFloat = 20.0 / baseWidth
        let calculatedTitleSize = currentWidth * titleRatio
        let cappedTitleSize = min(calculatedTitleSize, 30.0)
        
        PlaceName.font = UIFont.systemFont(ofSize: cappedTitleSize, weight: .semibold)
        let detailRatio: CGFloat = 12.0 / baseWidth
        let calculatedDetailSize = currentWidth * detailRatio
        let cappedDetailSize = min(calculatedDetailSize, 18.0)
        
        NoSpecies.font = UIFont.systemFont(ofSize: cappedDetailSize, weight: .regular)
        Distance.font = UIFont.systemFont(ofSize: cappedDetailSize, weight: .regular)
        Date.font = UIFont.systemFont(ofSize: cappedDetailSize, weight: .regular)
    }
    func configure(with prediction: HotspotPrediction) {
            
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
        
        if let radius = prediction.radius, let centerCoord = prediction.areaBoundary.first, prediction.areaBoundary.count == 1 {
        
            let circle = MKCircle(center: centerCoord, radius: radius)
            mapView.addOverlay(circle)
            
            let padding: CGFloat = 20
            mapView.setVisibleMapRect(circle.boundingMapRect, edgePadding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding), animated: false)
            
        } else if !prediction.areaBoundary.isEmpty {
            let polygon = HotspotBoundaryPolygon(coordinates: prediction.areaBoundary,
                                                 count: prediction.areaBoundary.count)
            mapView.addOverlay(polygon)

			if prediction.areaBoundary.first != nil {
                let zoomPolyline = MKPolyline(coordinates: prediction.areaBoundary,
                                              count: prediction.areaBoundary.count)
                zoomToFitOverlays(for: zoomPolyline)
            }
        }
        
        for hotspot in prediction.hotspots {
            let annotation = HotspotBirdAnnotation()
            annotation.coordinate = hotspot.coordinate
            annotation.imageName = hotspot.birdImageName
            annotation.title = "Bird Sighting"
            annotationsToAdd.append(annotation)
        }
        
        mapView.addAnnotations(annotationsToAdd)
    }

    private func zoomToFitOverlays(for pathLine: MKPolyline) {
        let rect = pathLine.boundingMapRect
        let edgePadding = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
    }
}



// MARK: - Map Delegate (Styling Hotspots)

extension HotspotCellCollectionViewCell {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if let polygon = overlay as? HotspotBoundaryPolygon {
            
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
        
        guard let hotspotAnnotation = annotation as? HotspotBirdAnnotation else {
            return nil
        }
        
        let identifier = "HotspotBirdPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: hotspotAnnotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }

        let colorStack: [UIColor] = [
            .systemRed,
            .systemBlue,
            .systemGreen,
            .systemOrange,
            .systemPurple,
            .systemPink,
            .systemTeal,
            .systemIndigo
        ]
        
        if let index = mapView.annotations.firstIndex(where: { $0 === annotation }) {
            let colorIndex = index % colorStack.count
            annotationView?.markerTintColor = colorStack[colorIndex]
        } else {
            annotationView?.markerTintColor = .systemGray 
        }
        
        annotationView?.glyphImage = UIImage(systemName: "bird.fill")
        
        return annotationView
    }
}
