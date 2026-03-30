
import UIKit
import MapKit
import CoreLocation

private final class MigrationPointAnnotation: MKPointAnnotation {
    enum PointType {
        case start
        case end
    }

    let pointType: PointType

    init(coordinate: CLLocationCoordinate2D, pointType: PointType) {
        self.pointType = pointType
        super.init()
        self.coordinate = coordinate
        self.title = pointType == .start ? "Start Point" : "End Point"
    }
}

private enum MigrationRouteStyle {
    static let startColor = UIColor.systemGreen.withAlphaComponent(0.6)
    static let endColor = UIColor.systemRed.withAlphaComponent(0.6)
}

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
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    private var sightingsCache: [Int: [RelevantSighting]] = [:]
    private var routeLocationNamesCache: [Int: (start: String, end: String)] = [:]
    private var previousPillBounds: CGRect = .zero
    private var previousCardBounds: CGRect = .zero
    private var locationLookupToken: UUID?

    private struct MLDataSnapshot: Decodable {
        let birdId: String
        let trajectoryPaths: [Path]

        struct Path: Decodable {
            let week: Int
            let lat: Double
            let lon: Double
        }
    }
    
    private var currentSpeciesIndex: Int = 0 {
        didSet {
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
        
        let addIcon = UIImage(named: "SF_addToWatchlist")?.withRenderingMode(.alwaysTemplate)
            ?? UIImage(systemName: "list.bullet.badge.plus")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: addIcon, style: .plain, target: self, action: #selector(didTapAddToWatchlist))
        
        
        let pillBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        pillBlur.frame = pillView.bounds
        pillBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pillBlur.layer.cornerRadius = 20
        pillBlur.layer.masksToBounds = true
        pillBlur.isUserInteractionEnabled = false
        
        pillView.backgroundColor = .clear
        pillView.insertSubview(pillBlur, at: 0)
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
        infoCardView.layer.masksToBounds = false
        
        birdImageView.layer.cornerRadius = 16
        birdImageView.clipsToBounds = true
        birdImageView.contentMode = .scaleAspectFill
        subtitleLabel.numberOfLines = 0
        
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
        navigationItem.rightBarButtonItem?.tintColor = .black
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(tap)
    }
    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let tapPoint = gesture.location(in: mapView)
        let visibleMapRect = mapView.visibleMapRect
        
        for overlay in mapView.overlays {
            if let polyline = overlay as? PredictedPathPolyline {
                guard polyline.boundingMapRect.intersects(visibleMapRect) else { continue }
                
                let points = polyline.points()
                let count = polyline.pointCount
                var found = false
                
                for i in 0..<(count - 1) {
                    let midMapPoint = MKMapPoint(
                        x: (points[i].x + points[i+1].x) / 2,
                        y: (points[i].y + points[i+1].y) / 2
                    )
                    guard visibleMapRect.contains(midMapPoint) else { continue }
                    
                    let p1 = mapView.convert(points[i].coordinate, toPointTo: mapView)
                    let p2 = mapView.convert(points[i+1].coordinate, toPointTo: mapView)
                    
                    if distanceToSegment(p: tapPoint, v: p1, w: p2) < 20 {
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
        
        let relevantSightings: [RelevantSighting]
        if let cached = sightingsCache[currentSpeciesIndex] {
            relevantSightings = cached
        } else {
            let dbSightings = HomeManager.shared.getRelevantSightings(for: input)
            if dbSightings.isEmpty {
                relevantSightings = loadMLSightingsIfNeeded(for: input)
            } else {
                relevantSightings = dbSightings
            }
            sightingsCache[currentSpeciesIndex] = relevantSightings
        }
        
        let coordinates = relevantSightings.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
        }

        resolveRouteLocationNames(for: currentSpeciesIndex, coordinates: coordinates)

        if let startCoordinate = coordinates.first {
            mapView.addAnnotation(MigrationPointAnnotation(coordinate: startCoordinate, pointType: .start))
        }
        if coordinates.count > 1, let endCoordinate = coordinates.last {
            mapView.addAnnotation(MigrationPointAnnotation(coordinate: endCoordinate, pointType: .end))
        }
        
        if coordinates.count > 1 {
            let polyline = PredictedPathPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            let polylineRect = polyline.boundingMapRect
            mapView.setVisibleMapRect(polylineRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 250, right: 50), animated: true)
        }
    }

    private func loadMLSightingsIfNeeded(for input: BirdDateInput) -> [RelevantSighting] {
        guard let url = Bundle.main.url(forResource: "MLdata", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(MLDataSnapshot.self, from: data),
              snapshot.birdId.caseInsensitiveCompare(input.species.id) == .orderedSame else {
            return []
        }

        return snapshot.trajectoryPaths
            .map { RelevantSighting(lat: $0.lat, lon: $0.lon, week: $0.week) }
            .sorted { $0.week < $1.week }
    }

    private func updateCardForCurrentIndex() {
        guard !predictionInputs.isEmpty, currentSpeciesIndex < predictionInputs.count else { return }
        
        let input = predictionInputs[currentSpeciesIndex]
        
        birdImageView.image = UIImage(named: input.species.imageName)
        titleLabel.text = input.species.name

        let dateRangeText: String
        if let start = input.startDate, let end = input.endDate {
            dateRangeText = "\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))"
        } else {
            dateRangeText = "Date range not set"
        }
        subtitleLabel.attributedText = buildSubtitleAttributedText(dateRangeText: dateRangeText, speciesIndex: currentSpeciesIndex)
        
        pageControl.numberOfPages = predictionInputs.count
        pageControl.currentPage = currentSpeciesIndex
        
        pillLabel.text = "\(predictionInputs.count) Species"
    }

    private func buildSubtitleAttributedText(dateRangeText: String, speciesIndex: Int) -> NSAttributedString {
        guard let locations = routeLocationNamesCache[speciesIndex] else {
            return NSAttributedString(
                string: dateRangeText,
                attributes: [.foregroundColor: subtitleLabel.textColor ?? .secondaryLabel]
            )
        }

        let dateColor = subtitleLabel.textColor ?? .secondaryLabel
        let routeText = NSMutableAttributedString(
            string: "\(dateRangeText)\n",
            attributes: [.foregroundColor: dateColor]
        )

        routeText.append(NSAttributedString(
            string: locations.start,
            attributes: [.foregroundColor: dateColor]
        ))
        routeText.append(NSAttributedString(
            string: "  -  ",
            attributes: [.foregroundColor: dateColor]
        ))
        routeText.append(NSAttributedString(
            string: locations.end,
            attributes: [.foregroundColor: dateColor]
        ))

        return routeText
    }

    private func resolveRouteLocationNames(for speciesIndex: Int, coordinates: [CLLocationCoordinate2D]) {
        guard routeLocationNamesCache[speciesIndex] == nil,
              let startCoordinate = coordinates.first,
              let endCoordinate = coordinates.last else {
            return
        }

        let token = UUID()
        locationLookupToken = token

        reverseGeocodeDisplayName(for: startCoordinate) { [weak self] startName in
            guard let self = self else { return }

            let finish: (String) -> Void = { endName in
                self.routeLocationNamesCache[speciesIndex] = (start: startName, end: endName)
                guard self.currentSpeciesIndex == speciesIndex,
                      self.locationLookupToken == token else { return }
                self.updateCardForCurrentIndex()
            }

            let samePoint = abs(startCoordinate.latitude - endCoordinate.latitude) < 0.000_001 &&
                abs(startCoordinate.longitude - endCoordinate.longitude) < 0.000_001

            if samePoint {
                finish(startName)
                return
            }

            self.reverseGeocodeDisplayName(for: endCoordinate) { endName in
                finish(endName)
            }
        }
    }

    private func reverseGeocodeDisplayName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            let fallback = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
            guard let placemark = placemarks?.first else {
                completion(fallback)
                return
            }

            let city = placemark.locality ?? placemark.subLocality ?? placemark.name
            let region = placemark.administrativeArea ?? placemark.country

            if let city, let region, !city.isEmpty, !region.isEmpty, city != region {
                completion("\(city), \(region)")
            } else if let city, !city.isEmpty {
                completion(city)
            } else if let region, !region.isEmpty {
                completion(region)
            } else {
                completion(fallback)
            }
        }
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
        guard predictionInputs.indices.contains(currentSpeciesIndex) else { return }
        let species = predictionInputs[currentSpeciesIndex].species
        let manager = WatchlistManager.shared

        let bird: Bird
        if let birdID = UUID(uuidString: species.id),
           let matchedByID = try? manager.fetchBird(bird_id: birdID) {
            bird = matchedByID
        } else if let matchedByName = manager.findBird(byName: species.name) {
            bird = matchedByName
        } else {
            bird = manager.createBird(name: species.name)
        }

        do {
            try manager.addBirds([bird], to: WatchlistConstants.myWatchlistID, asObserved: false)
            let alert = UIAlertController(title: "Watchlist", message: "\(species.name) added to your watchlist.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(title: "Error", message: "Failed to add bird to watchlist: \(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
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
            renderer.strokeColor = .systemBlue
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        guard let migrationPoint = annotation as? MigrationPointAnnotation else { return nil }

        let reuseIdentifier = "MigrationPointMarker"
        let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: migrationPoint, reuseIdentifier: reuseIdentifier)
        view.annotation = migrationPoint
        view.canShowCallout = true
        view.displayPriority = .required

        switch migrationPoint.pointType {
        case .start:
            view.markerTintColor = MigrationRouteStyle.startColor
            view.glyphText = "S"
        case .end:
            view.markerTintColor = MigrationRouteStyle.endColor
            view.glyphText = "E"
        }

        return view
    }
}

class ArrowPolylineRenderer: MKPolylineRenderer {
    private static let normalStrokeColor = UIColor.systemBlue.withAlphaComponent(0.6)
    private static let highlightedArrowColor = UIColor.systemYellow.cgColor
    private static let normalArrowColor = UIColor.white.cgColor
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        
        let predictedPolyline = self.overlay as? PredictedPathPolyline
        let isHighlighted = predictedPolyline?.isSelected ?? false
        if isHighlighted {
            self.strokeColor = .systemBlue
            self.lineWidth = 6
        } else {
            self.strokeColor = ArrowPolylineRenderer.normalStrokeColor
            self.lineWidth = 4
        }
        
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        let polyline = self.polyline
        let mapPoints = polyline.points()
        let pointCount = polyline.pointCount
        
        if pointCount < 2 { return }
        let arrowColor = isHighlighted ? ArrowPolylineRenderer.highlightedArrowColor : ArrowPolylineRenderer.normalArrowColor
        context.setFillColor(arrowColor)
        let arrowSize: CGFloat = 10.0 / zoomScale
        let halfArrow = arrowSize / 2
        for i in 0..<(pointCount - 1) {
            let start = mapPoints[i]
            let end = mapPoints[i+1]
            let midX = (start.x + end.x) / 2
            let midY = (start.y + end.y) / 2
            let midPoint = MKMapPoint(x: midX, y: midY)
            if !mapRect.contains(midPoint) { continue }
            let point = self.point(for: midPoint)
            let dx = end.x - start.x
            let dy = -(end.y - start.y)
            let angle = atan2(dy, dx)
            context.saveGState()
            context.translateBy(x: point.x, y: point.y)
            context.rotate(by: angle)
            
            context.beginPath()
            context.move(to: CGPoint(x: halfArrow, y: 0))
            context.addLine(to: CGPoint(x: -halfArrow, y: -halfArrow))
            context.addLine(to: CGPoint(x: -halfArrow, y: halfArrow))
            context.closePath()
            context.fillPath()
            
            context.restoreGState()
        }
    }
}
