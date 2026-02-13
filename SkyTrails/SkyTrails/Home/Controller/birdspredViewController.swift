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
        setupTraitChangeHandling()
        setupUI()
        setupMap()
        applySemanticAppearance()
        
        if !predictionInputs.isEmpty {
            currentSpeciesIndex = 0
            showCardState()
        } else {
            pillView.isHidden = true
            infoCardView.isHidden = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if traitCollection.userInterfaceStyle != .dark {
            pillView.layer.shadowPath = UIBezierPath(roundedRect: pillView.bounds, cornerRadius: 20).cgPath
            infoCardView.layer.shadowPath = UIBezierPath(roundedRect: infoCardView.bounds, cornerRadius: 24).cgPath
        }
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }
    
    private func setupUI() {
        self.title = ""
        
        let addIcon = UIImage(systemName: "plus.circle.fill")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: addIcon, style: .plain, target: self, action: #selector(didTapAddToWatchlist))
        
        
        let pillBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        pillBlur.frame = pillView.bounds
        pillBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pillBlur.layer.cornerRadius = 20
        pillBlur.layer.masksToBounds = true
        pillBlur.isUserInteractionEnabled = false
        
        pillView.backgroundColor = .clear
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
        cardBlur.layer.cornerRadius = 24
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

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.currentPageIndicatorTintColor = .systemBlue
        pillLabel.textColor = .label
        titleLabel.textColor = .label
        subtitleLabel.textColor = .secondaryLabel

        if isDarkMode {
            pillView.layer.shadowOpacity = 0
            pillView.layer.shadowRadius = 0
            pillView.layer.shadowOffset = .zero
            pillView.layer.shadowPath = nil
            infoCardView.layer.shadowOpacity = 0
            infoCardView.layer.shadowRadius = 0
            infoCardView.layer.shadowOffset = .zero
            infoCardView.layer.shadowPath = nil
        } else {
            pillView.layer.shadowColor = UIColor.black.cgColor
            pillView.layer.shadowOpacity = 0.08
            pillView.layer.shadowOffset = CGSize(width: 0, height: 3)
            pillView.layer.shadowRadius = 6
            pillView.layer.shadowPath = UIBezierPath(roundedRect: pillView.bounds, cornerRadius: 20).cgPath

            infoCardView.layer.shadowColor = UIColor.black.cgColor
            infoCardView.layer.shadowOpacity = 0.08
            infoCardView.layer.shadowOffset = CGSize(width: 0, height: 3)
            infoCardView.layer.shadowRadius = 6
            infoCardView.layer.shadowPath = UIBezierPath(roundedRect: infoCardView.bounds, cornerRadius: 24).cgPath
        }
    }
    
    private func setupMap() {
        mapView.delegate = self
        
        let center = CLLocationCoordinate2D(latitude: 22.0, longitude: 78.0)
        let span = MKCoordinateSpan(latitudeDelta: 25.0, longitudeDelta: 25.0)
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
        
        // Add Tap Gesture for Path Highlighting
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(tap)
    }
    
    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let tapPoint = gesture.location(in: mapView)
        
        for overlay in mapView.overlays {
            if let polyline = overlay as? PredictedPathPolyline {
                let points = polyline.points()
                let count = polyline.pointCount
                var found = false
                
                // Simple hit testing against polyline segments
                for i in 0..<(count - 1) {
                    let p1 = mapView.convert(points[i].coordinate, toPointTo: mapView)
                    let p2 = mapView.convert(points[i+1].coordinate, toPointTo: mapView)
                    
                    if distanceToSegment(p: tapPoint, v: p1, w: p2) < 20 { // 20pt hit area
                        found = true
                        break
                    }
                }
                
                if found {
                    polyline.isSelected.toggle()
                    if let renderer = mapView.renderer(for: polyline) {
                        renderer.setNeedsDisplay()
                    }
                }
            }
        }
    }
    
    // MARK: - Geometry Helpers
    
    private func distanceToSegment(p: CGPoint, v: CGPoint, w: CGPoint) -> CGFloat {
        let l2 = dist2(v, w)
        if l2 == 0 { return dist2(p, v).squareRoot() }
        var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
        t = max(0, min(1, t))
        let projection = CGPoint(x: v.x + t * (w.x - v.x), y: v.y + t * (w.y - v.y))
        return dist2(p, projection).squareRoot()
    }

    private func dist2(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return (p1.x - p2.x)*(p1.x - p2.x) + (p1.y - p2.y)*(p1.y - p2.y)
    }
    
    private func updateMapForCurrentBird() {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        let relevantSightings = HomeManager.shared.getRelevantSightings(for: input)
        
        var coordinates: [CLLocationCoordinate2D] = []
        
        for sighting in relevantSightings {
            let coord = CLLocationCoordinate2D(latitude: sighting.lat, longitude: sighting.lon)
            coordinates.append(coord)
        }
        
        if coordinates.count > 1 {
            let polyline = PredictedPathPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            // Zoom to show path
            let polylineRect = polyline.boundingMapRect
            mapView.setVisibleMapRect(polylineRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 250, right: 50), animated: true)
        }
    }
    
    private func updateCardForCurrentIndex() {
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        print("🔍 [birdspredVC] Updating card for \(input.species.name)")
        print("🔍 [birdspredVC] Received dates - Start: \(String(describing: input.startDate)), End: \(String(describing: input.endDate))")
        
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

extension birdspredViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? PredictedPathPolyline {
            return ArrowPolylineRenderer(overlay: polyline)
        }
        
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            
            if overlay is ProgressPathPolyline {
                renderer.strokeColor = .systemBlue
            } else {
                renderer.strokeColor = .systemBlue 
            }
            
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        // No custom annotations needed for now
        return nil
    }
}

// MARK: - Arrow Renderer

class ArrowPolylineRenderer: MKPolylineRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        
        let predictedPolyline = self.overlay as? PredictedPathPolyline
        let isHighlighted = predictedPolyline?.isSelected ?? false
        
        // Style lines
        if isHighlighted {
            self.strokeColor = .systemBlue
            self.lineWidth = 6
        } else {
            self.strokeColor = UIColor.systemBlue.withAlphaComponent(0.6)
            self.lineWidth = 4
        }
        
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        
        // Draw arrows
        guard let polyline = self.polyline as? MKPolyline else { return }
        
        // Arrow styling
        let arrowColor = isHighlighted ? UIColor.systemYellow.cgColor : UIColor.white.cgColor
        context.setFillColor(arrowColor)
        
        let mapPoints = polyline.points()
        let pointCount = polyline.pointCount
        
        if pointCount < 2 { return }
        
        // Iterate segments
        for i in 0..<(pointCount - 1) {
            let start = mapPoints[i]
            let end = mapPoints[i+1]
            
            // Calculate Midpoint
            let midX = (start.x + end.x) / 2
            let midY = (start.y + end.y) / 2
            let midPoint = MKMapPoint(x: midX, y: midY)
            
            // Optimization: Skip if not visible
            if !mapRect.contains(midPoint) { continue }
            
            // Convert to screen/context point
            let point = self.point(for: midPoint)
            
            // Calculate Angle
            let startPt = self.point(for: start)
            let endPt = self.point(for: end)
            let angle = atan2(endPt.y - startPt.y, endPt.x - startPt.x)
            
            // Draw
            context.saveGState()
            context.translateBy(x: point.x, y: point.y)
            context.rotate(by: angle)
            
            // Arrow size - roughly 10pt
            let arrowSize: CGFloat = 10.0 / zoomScale
            
            context.beginPath()
            context.move(to: CGPoint(x: arrowSize/2, y: 0)) // Tip
            context.addLine(to: CGPoint(x: -arrowSize/2, y: -arrowSize/2)) // Bottom Left
            context.addLine(to: CGPoint(x: -arrowSize/2, y: arrowSize/2)) // Bottom Right
            context.closePath()
            context.fillPath()
            
            context.restoreGState()
        }
    }
}
