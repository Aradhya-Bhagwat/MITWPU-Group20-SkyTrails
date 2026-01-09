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
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
 
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: hotspotAnnotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = false // Prevent callout conflict with clipping
        } else {
            annotationView?.annotation = annotation
        }
        
        if let imageName = hotspotAnnotation.imageName,
           let birdImage = UIImage(named: imageName) {
            
            let outerPinSize: CGFloat = 40.0
            let innerImageSize: CGFloat = 32.0
            let pinHeight: CGFloat = 50.0
            
            let pinBaseSize = CGSize(width: outerPinSize, height: pinHeight)
            let renderer = UIGraphicsImageRenderer(size: pinBaseSize)
            
            
            let finalPinImage = renderer.image { context in
                let cgContext = context.cgContext
                let pinColor = UIColor(red: 12/255, green: 70/255, blue: 156/255, alpha: 0.9).cgColor// Use dark blue for pin body
                
                cgContext.beginPath()
                cgContext.move(to: CGPoint(x: pinBaseSize.width / 2 , y: pinHeight)) 
                cgContext.addLine(to: CGPoint(x: 12, y: outerPinSize - 4))
                cgContext.addLine(to: CGPoint(x: pinBaseSize.width - 12, y: outerPinSize - 4))
                cgContext.closePath()
                cgContext.setFillColor(pinColor)
                cgContext.fillPath()
                
                let outerCircleRect = CGRect(x: 0, y: 0, width: outerPinSize, height: outerPinSize)
                cgContext.addEllipse(in: outerCircleRect)
                cgContext.setFillColor(pinColor)
                cgContext.fillPath()
                let whiteBorderRect = CGRect(x: 2, y: 2, width: outerPinSize - 4, height: outerPinSize - 4)
                cgContext.addEllipse(in: whiteBorderRect)
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fillPath()

                let imageRect = CGRect(x: (outerPinSize - innerImageSize) / 2,
                                       y: (outerPinSize - innerImageSize) / 2,
                                       width: innerImageSize,
                                       height: innerImageSize)
                
                cgContext.addEllipse(in: imageRect)
                cgContext.clip()
                
                birdImage.draw(in: imageRect)
            }
            
            annotationView?.image = finalPinImage
            annotationView?.centerOffset = CGPoint(x: 0, y: pinHeight / 50 - 4)
            annotationView?.layer.cornerRadius = 0
            annotationView?.layer.masksToBounds = false
        }
        
        return annotationView
    }
}
