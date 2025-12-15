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
    
    // Floating UI Outlets (Linked from Storyboard)
    @IBOutlet weak var pillView: UIView!
    @IBOutlet weak var pillLabel: UILabel!
    
    @IBOutlet weak var infoCardView: UIView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var pageControl: UIPageControl!
    
    // Logic: Received processed inputs
    var predictionInputs: [BirdDateInput] = []
    
    // State Manager for selected species index
    private var currentSpeciesIndex: Int = 0 {
        didSet {
            // Update UI and Map whenever index changes
            updateCardForCurrentIndex()
            updateMapForCurrentBird()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMap()
        
        // Initial State
        if !predictionInputs.isEmpty {
            currentSpeciesIndex = 0 // Triggers updates
            showCardState()
        } else {
            pillView.isHidden = true
            infoCardView.isHidden = true
        }
    }
    
    private func setupUI() {
        self.title = "" // Remove title
        
        // Add "Add to Watchlist" button
        let addIcon = UIImage(systemName: "plus.circle.fill")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: addIcon, style: .plain, target: self, action: #selector(didTapAddToWatchlist))
        
        // --- 1. Pill Style (Liquid Glass) ---
        pillView.backgroundColor = .clear
        let pillBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        pillBlur.frame = pillView.bounds
        pillBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pillBlur.layer.cornerRadius = 20
        pillBlur.layer.masksToBounds = true
        pillBlur.isUserInteractionEnabled = false // Allow touches to pass to view
        pillView.insertSubview(pillBlur, at: 0)
        
        // Shadow for Pill
        pillView.layer.shadowColor = UIColor.black.cgColor
        pillView.layer.shadowOpacity = 0.2
        pillView.layer.shadowOffset = CGSize(width: 0, height: 4)
        pillView.layer.shadowRadius = 8
        pillView.layer.masksToBounds = false
        
        // Gesture
        let pillTap = UITapGestureRecognizer(target: self, action: #selector(didTapPill))
        pillView.addGestureRecognizer(pillTap)
        
        // --- 2. Card Style (Liquid Glass) ---
        infoCardView.backgroundColor = .clear
        let cardBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        cardBlur.frame = infoCardView.bounds
        cardBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cardBlur.layer.cornerRadius = 24 // More rounded
        cardBlur.layer.masksToBounds = true
        cardBlur.isUserInteractionEnabled = false
        infoCardView.insertSubview(cardBlur, at: 0)
        
        // Shadow for Card
        infoCardView.layer.cornerRadius = 24
        infoCardView.layer.shadowColor = UIColor.black.cgColor
        infoCardView.layer.shadowOpacity = 0.25
        infoCardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        infoCardView.layer.shadowRadius = 12
        infoCardView.layer.masksToBounds = false
        
        // Image Styling
        birdImageView.layer.cornerRadius = 16
        birdImageView.clipsToBounds = true
        birdImageView.contentMode = .scaleAspectFill
        
        // Gestures for Card
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        infoCardView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        infoCardView.addGestureRecognizer(swipeRight)
        
        // Tap to collapse
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(didTapCard))
        infoCardView.addGestureRecognizer(cardTap)
    }
    
    private func setupMap() {
        mapView.delegate = self
        // Default center
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
        // 1. Clear Map
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        guard let start = input.startDate, let end = input.endDate else { return }
        
        let startWeek = Calendar.current.component(.weekOfYear, from: start)
        let endWeek = Calendar.current.component(.weekOfYear, from: end)
        
        // 2. Filter & Collect Sightings
        var relevantSightings: [Sighting] = []
        
        for sighting in input.species.sightings {
            var isMatch = false
            
            // Check logic (handling year wrap)
            if startWeek <= endWeek {
                if sighting.week >= startWeek && sighting.week <= endWeek { isMatch = true }
            } else {
                if sighting.week >= startWeek || sighting.week <= endWeek { isMatch = true }
            }
            
            // Flexibility window (+/- 2 weeks)
            if !isMatch {
                let s = sighting.week
                let sStart = startWeek
                let sEnd = endWeek
                
                // Simple distance check in a cyclic 52-week system
                let distToStart = min(abs(s - sStart), 52 - abs(s - sStart))
                let distToEnd = min(abs(s - sEnd), 52 - abs(s - sEnd))
                
                if distToStart <= 2 || distToEnd <= 2 { isMatch = true }
            }
            
            if isMatch {
                relevantSightings.append(sighting)
            }
        }
        
        // 3. Sort Sightings by Week (for logical path flow)
        // Handle year wrap (e.g., Nov to Feb) for correct path drawing
        if startWeek > endWeek {
            relevantSightings.sort { s1, s2 in
                // If a week is small (e.g., 2), treat it as 54 (2+52) so it comes after 48
                let w1 = s1.week < startWeek ? s1.week + 52 : s1.week
                let w2 = s2.week < startWeek ? s2.week + 52 : s2.week
                return w1 < w2
            }
        } else {
            relevantSightings.sort { $0.week < $1.week }
        }
        
        // 4. Add Annotations (Pins)
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
        
        // 5. Add Polyline (Blue Line)
        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        // 6. Zoom to Fit
        if !coordinates.isEmpty {
            // Calculate bounding box
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
            } else {
                // Optional: Loop to end?
                // currentSpeciesIndex = predictionInputs.count - 1
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
