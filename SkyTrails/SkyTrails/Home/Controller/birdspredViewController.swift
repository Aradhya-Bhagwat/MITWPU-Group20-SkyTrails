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
    
    // MARK: - Performance: Cached DateFormatter (Fix 4)
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Performance: Sightings cache to avoid redundant SwiftData fetches (Fix 3)
    private var sightingsCache: [Int: [RelevantSighting]] = [:]
    
    // MARK: - Performance: Track previous bounds to avoid redundant shadow path rebuilds (Fix 5)
    private var previousPillBounds: CGRect = .zero
    private var previousCardBounds: CGRect = .zero
    
    private var currentSpeciesIndex: Int = 0 {
        didSet {
            // Fix 8: Guard against redundant updates
            guard oldValue != currentSpeciesIndex else { return }
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
            // Directly call update methods instead of relying on didSet for initial setup,
            // since didSet won't fire when setting to the same default value (0).
            updateCardForCurrentIndex()
            updateMapForCurrentBird()
            showCardState()
        } else {
            pillView.isHidden = true
            infoCardView.isHidden = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Fix 5: Only rebuild shadow paths when bounds actually change
        if traitCollection.userInterfaceStyle != .dark {
            if pillView.bounds != previousPillBounds {
                previousPillBounds = pillView.bounds
                pillView.layer.shadowPath = UIBezierPath(roundedRect: pillView.bounds, cornerRadius: 20).cgPath
            }
            if infoCardView.bounds != previousCardBounds {
                previousCardBounds = infoCardView.bounds
                infoCardView.layer.shadowPath = UIBezierPath(roundedRect: infoCardView.bounds, cornerRadius: 24).cgPath
            }
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
        
        let addIcon = UIImage(systemName: "custom.list.bullet.badge.plus")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: addIcon, style: .plain, target: self, action: #selector(didTapAddToWatchlist))
        
        
        let pillBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        pillBlur.frame = pillView.bounds
        pillBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pillBlur.layer.cornerRadius = 20
        pillBlur.layer.masksToBounds = true
        pillBlur.isUserInteractionEnabled = false
        
        pillView.backgroundColor = .clear
        pillView.insertSubview(pillBlur, at: 0)
        // Fix 7: Removed duplicate shadow setup — applySemanticAppearance() handles all shadow config
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
        // Fix 7: Removed duplicate shadow setup — applySemanticAppearance() handles all shadow config
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
    
    // Fix 2: Optimized hit testing — skip off-screen overlays via bounding rect check,
    // and convert only visible points to screen space
    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let tapPoint = gesture.location(in: mapView)
        let visibleMapRect = mapView.visibleMapRect
        
        for overlay in mapView.overlays {
            if let polyline = overlay as? PredictedPathPolyline {
                // Early cull: skip overlays not visible on screen
                guard polyline.boundingMapRect.intersects(visibleMapRect) else { continue }
                
                let points = polyline.points()
                let count = polyline.pointCount
                var found = false
                
                for i in 0..<(count - 1) {
                    // Skip segments whose midpoint is off-screen
                    let midMapPoint = MKMapPoint(
                        x: (points[i].x + points[i+1].x) / 2,
                        y: (points[i].y + points[i+1].y) / 2
                    )
                    guard visibleMapRect.contains(midMapPoint) else { continue }
                    
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
    
    // Fix 3: Cache sightings per species index to avoid redundant SwiftData fetches on re-swipe
    // Fix 10: Use map() instead of manual loop for coordinate building
    private func updateMapForCurrentBird() {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        
        let relevantSightings: [RelevantSighting]
        if let cached = sightingsCache[currentSpeciesIndex] {
            relevantSightings = cached
        } else {
            relevantSightings = HomeManager.shared.getRelevantSightings(for: input)
            sightingsCache[currentSpeciesIndex] = relevantSightings
        }
        
        let coordinates = relevantSightings.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
        }
        
        if coordinates.count > 1 {
            let polyline = PredictedPathPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            // Zoom to show path
            let polylineRect = polyline.boundingMapRect
            mapView.setVisibleMapRect(polylineRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 250, right: 50), animated: true)
        }
    }
    
    // Fix 4: Use cached dateFormatter instead of creating one per call
    // Fix 6: Removed debug print statements
    private func updateCardForCurrentIndex() {
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        
        birdImageView.image = UIImage(named: input.species.imageName)
        titleLabel.text = input.species.name
        
        if let start = input.startDate, let end = input.endDate {
            subtitleLabel.text = "\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))"
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
    
    // Fix 9: Simplified dead-code branch — both paths set same color
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? PredictedPathPolyline {
            return ArrowPolylineRenderer(overlay: polyline)
        }
        
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            renderer.strokeColor = .systemBlue
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

// MARK: - Arrow Renderer (Fix 1: Performance-optimized)

class ArrowPolylineRenderer: MKPolylineRenderer {
    
    // Cache resolved colors to avoid repeated UIColor -> CGColor conversions in draw()
    private static let normalStrokeColor = UIColor.systemBlue.withAlphaComponent(0.6)
    private static let highlightedArrowColor = UIColor.systemYellow.cgColor
    private static let normalArrowColor = UIColor.white.cgColor
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        
        let predictedPolyline = self.overlay as? PredictedPathPolyline
        let isHighlighted = predictedPolyline?.isSelected ?? false
        
        // Fix 1a: Set style properties before super.draw() — these are checked by super
        // but setting them here (instead of outside draw) is acceptable since they depend
        // on the mutable isSelected state. The key optimization is caching the colors above.
        if isHighlighted {
            self.strokeColor = .systemBlue
            self.lineWidth = 6
        } else {
            self.strokeColor = ArrowPolylineRenderer.normalStrokeColor
            self.lineWidth = 4
        }
        
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        
        // Draw arrows
        let polyline = self.polyline
        let mapPoints = polyline.points()
        let pointCount = polyline.pointCount
        
        if pointCount < 2 { return }
        
        // Fix 1b: Cache arrow color and size outside the loop
        let arrowColor = isHighlighted ? ArrowPolylineRenderer.highlightedArrowColor : ArrowPolylineRenderer.normalArrowColor
        context.setFillColor(arrowColor)
        let arrowSize: CGFloat = 10.0 / zoomScale
        let halfArrow = arrowSize / 2
        
        // Iterate segments
        for i in 0..<(pointCount - 1) {
            let start = mapPoints[i]
            let end = mapPoints[i+1]
            
            // Calculate Midpoint in map space
            let midX = (start.x + end.x) / 2
            let midY = (start.y + end.y) / 2
            let midPoint = MKMapPoint(x: midX, y: midY)
            
            // Optimization: Skip if not visible
            if !mapRect.contains(midPoint) { continue }
            
            // Convert to screen/context point
            let point = self.point(for: midPoint)
            
            // Fix 1c: Compute angle using map-space delta to avoid 2 extra point(for:) calls.
            // Map-space Y is inverted relative to screen Y, so negate dy.
            let dx = end.x - start.x
            let dy = -(end.y - start.y)
            let angle = atan2(dy, dx)
            
            // Draw arrow
            context.saveGState()
            context.translateBy(x: point.x, y: point.y)
            context.rotate(by: angle)
            
            context.beginPath()
            context.move(to: CGPoint(x: halfArrow, y: 0))          // Tip
            context.addLine(to: CGPoint(x: -halfArrow, y: -halfArrow)) // Bottom Left
            context.addLine(to: CGPoint(x: -halfArrow, y: halfArrow))  // Bottom Right
            context.closePath()
            context.fillPath()
            
            context.restoreGState()
        }
    }
}
