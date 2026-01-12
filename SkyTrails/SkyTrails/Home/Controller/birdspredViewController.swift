//
//  birdspredViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit
import MapKit

class birdspredViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pillView: UIView!
    @IBOutlet weak var pillLabel: UILabel!
    @IBOutlet weak var infoCardView: UIView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var pageControl: UIPageControl!
    
    var predictionInputs: [BirdDateInput] = []
    
    private var currentSpeciesIndex: Int = 0 {
        didSet {
            updateCardForCurrentIndex()
            updateMapForCurrentBird()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMap()
        
        if !predictionInputs.isEmpty {
            currentSpeciesIndex = 0
            showCardState()
        } else {
            pillView.isHidden = true
            infoCardView.isHidden = true
        }
    }
    
    private func setupUI() {
        self.title = ""
        
        let addIcon = UIImage(systemName: "plus.circle.fill")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: addIcon, style: .plain, target: self, action: #selector(didTapAddToWatchlist))
        
        pillView.backgroundColor = .clear
        let pillBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        pillBlur.frame = pillView.bounds
        pillBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pillBlur.layer.cornerRadius = 20
        pillBlur.layer.masksToBounds = true
        pillBlur.isUserInteractionEnabled = false
        
        pillView.insertSubview(pillBlur, at: 0)
        pillView.layer.shadowColor = UIColor.black.cgColor
        pillView.layer.shadowOpacity = 0.2
        pillView.layer.shadowOffset = CGSize(width: 0, height: 4)
        pillView.layer.shadowRadius = 8
        pillView.layer.masksToBounds = false
        let pillTap = UITapGestureRecognizer(target: self, action: #selector(didTapPill))
        pillView.addGestureRecognizer(pillTap)
        
        
        let cardBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        cardBlur.frame = infoCardView.bounds
        cardBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cardBlur.layer.cornerRadius = 24 // More rounded
        cardBlur.layer.masksToBounds = true
        cardBlur.isUserInteractionEnabled = false
        
        infoCardView.backgroundColor = .clear
        infoCardView.insertSubview(cardBlur, at: 0)
        infoCardView.layer.cornerRadius = 24
        infoCardView.layer.shadowColor = UIColor.black.cgColor
        infoCardView.layer.shadowOpacity = 0.25
        infoCardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        infoCardView.layer.shadowRadius = 12
        infoCardView.layer.masksToBounds = false
        
        birdImageView.layer.cornerRadius = 16
        birdImageView.clipsToBounds = true
        birdImageView.contentMode = .scaleAspectFill
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        infoCardView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        infoCardView.addGestureRecognizer(swipeRight)
        
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(didTapCard))
        infoCardView.addGestureRecognizer(cardTap)
    }
    
    private func setupMap() {
        mapView.delegate = self
        
        let center = CLLocationCoordinate2D(latitude: 22.0, longitude: 78.0)
        let span = MKCoordinateSpan(latitudeDelta: 25.0, longitudeDelta: 25.0)
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
    }
    
    // MARK: - Update Logic
    
    private func updateCardForCurrentIndex() {
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        
        birdImageView.image = UIImage(named: input.species.imageName)
        titleLabel.text = input.species.name
        
        if let start = input.startDate, let end = input.endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            subtitleLabel.text = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            subtitleLabel.text = "Date range not set"
        }
        
        pageControl.numberOfPages = predictionInputs.count
        pageControl.currentPage = currentSpeciesIndex
        
        pillLabel.text = "\(predictionInputs.count) Species"
    }
    
    private func updateMapForCurrentBird() {
        
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        let relevantSightings = HomeManager.shared.getRelevantSightings(for: input)
        
        var annotations: [MKPointAnnotation] = []
        var coordinates: [CLLocationCoordinate2D] = []
        
        for sighting in relevantSightings {
            let coord = CLLocationCoordinate2D(latitude: sighting.lat, longitude: sighting.lon)
            coordinates.append(coord)
            
            let point = MKPointAnnotation()
            point.coordinate = coord
            point.title = input.species.name
            point.subtitle = "Week \(sighting.week)"
            annotations.append(point)
        }
        
        mapView.addAnnotations(annotations)
        
        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        if !coordinates.isEmpty {
            var zoomRect = MKMapRect.null
            for annotation in annotations {
                let annotationPoint = MKMapPoint(annotation.coordinate)
                let pointRect = MKMapRect(x: annotationPoint.x, y: annotationPoint.y, width: 0.1, height: 0.1)
                zoomRect = zoomRect.union(pointRect)
            }
            mapView.setVisibleMapRect(zoomRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 250, right: 50), animated: true)
        }
    }
    
    // MARK: - Interaction Handlers
    
    @objc private func didTapPill() {
        showCardState()
    }
    
    @objc private func didTapCard() {
        if predictionInputs.count > 1 {
            showPillState()
        }
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            if currentSpeciesIndex < predictionInputs.count - 1 {
                currentSpeciesIndex += 1
            } else {
                // Optional: Loop back to start?
                // currentSpeciesIndex = 0
            }
        } else if gesture.direction == .right {
            if currentSpeciesIndex > 0 {
                currentSpeciesIndex -= 1
            }
        }
    }

    @objc private func didTapAddToWatchlist() {
        let name = predictionInputs[currentSpeciesIndex].species.name
        let alert = UIAlertController(title: "Watchlist", message: "\(name) added to your watchlist.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - State Transitions
    
    private func showCardState() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.pillView.alpha = 0
            self.pillView.transform = CGAffineTransform(translationX: 0, y: 20)
            
            self.infoCardView.isHidden = false
            self.infoCardView.alpha = 1
            self.infoCardView.transform = .identity
        } completion: { _ in
            self.pillView.isHidden = true
        }
    }
    
    private func showPillState() {
        self.pillView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.infoCardView.alpha = 0
            self.infoCardView.transform = CGAffineTransform(translationX: 0, y: 20)
            
            self.pillView.alpha = 1
            self.pillView.transform = .identity
        } completion: { _ in
            self.infoCardView.isHidden = true
        }
    }
}

// MARK: - MapView Delegate

extension birdspredViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        
        let identifier = "BirdPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            annotationView?.markerTintColor = .systemBlue
            annotationView?.glyphImage = UIImage(systemName: "bird")
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
}
