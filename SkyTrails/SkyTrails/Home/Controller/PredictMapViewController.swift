
import UIKit
import MapKit
import QuartzCore

class PredictMapViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!

    private final class PredictionAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?

        init(
            coordinate: CLLocationCoordinate2D,
            title: String? = nil,
            subtitle: String? = nil
        ) {
            self.coordinate = coordinate
            self.title = title
            self.subtitle = subtitle
            super.init()
        }
    }
    
    private var currentChildVC: UIViewController?
    private var modalContainerView: UIView!
    private var modalTopConstraint: NSLayoutConstraint!
    private var originalTopConstant: CGFloat = 0
    private var maxTopY: CGFloat = 120
    private var minBottomY: CGFloat = 0
    private var initialLoadY: CGFloat = 0
    private var mapRenderToken: Int = 0
    private var currentGeoJSONOverlays: [MKOverlay] = []
    private var currentOutputInputs: [PredictionInputData] = []
    private var currentOutputUsesInputRadiusOverlay = false
    private var pendingOutputPredictions: [FinalPredictionResult]?
    
    private enum OverlayMode {
        case mapItemArea
        case inputRadius
        case none
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMap()
        setupCustomModal()
        mapView.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // 3-Second Janitor: Clear memory after 3 seconds to prevent RAM bloat
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            await MainActor.run {
                if !self.currentGeoJSONOverlays.isEmpty {
                    self.mapView.removeOverlays(self.currentGeoJSONOverlays)
                    self.currentGeoJSONOverlays.removeAll()
                }
            }
        }
    }
        
    private func updateMap(
        with inputs: [PredictionInputData],
        predictions _: [FinalPredictionResult],
        overlayMode: OverlayMode = .mapItemArea
    ) {
        mapRenderToken += 1
        let currentToken = mapRenderToken
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        currentGeoJSONOverlays.removeAll()

        var annotations: [MKAnnotation] = []
        var locationCoordinates: [CLLocationCoordinate2D] = []
        let areaAnchorCoordinates: [CLLocationCoordinate2D] = inputs.compactMap { input in
            guard let lat = input.latitude, let lon = input.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        for input in inputs {
            guard let lat = input.latitude,
                  let lon = input.longitude else { continue }
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            locationCoordinates.append(coordinate)
            let annotation = PredictionAnnotation(
                coordinate: coordinate,
                title: nil,
                subtitle: nil
            )
            annotations.append(annotation)

            if overlayMode == .none { continue }

            if overlayMode == .inputRadius {
                let radiusKm = max(0.2, Double(input.areaValue))
                let circle = MKCircle(center: coordinate, radius: radiusKm * 1000.0)
                mapView.addOverlay(circle)
                continue
            }

            Task { [weak self] in
                guard let self else { return }
                let overlay = await self.resolvePredictionAreaOverlay(
                    locationName: input.locationName,
                    coordinate: coordinate
                )
                await MainActor.run {
                    guard self.mapRenderToken == currentToken else { return }
                    switch overlay {
                    case .polygon(let coordinates):
                        guard coordinates.count >= 3 else { return }
                        var coords = coordinates
                        let polygon = MKPolygon(coordinates: &coords, count: coords.count)
                        self.mapView.addOverlay(polygon)
                    case .circle(let radiusKm):
                        let circle = MKCircle(center: coordinate, radius: radiusKm * 1000.0)
                        self.mapView.addOverlay(circle)
                    }
                    self.applyResultMapViewport(anchorCoordinates: areaAnchorCoordinates, animated: true)
                }
            }
        }
        
        mapView.addAnnotations(annotations)
        applyResultMapViewport(anchorCoordinates: areaAnchorCoordinates.isEmpty ? locationCoordinates : areaAnchorCoordinates, animated: true)
        
    }

    private enum PredictionAreaOverlay {
        case polygon([CLLocationCoordinate2D])
        case circle(radiusKm: Double)
    }

    private func resolvePredictionAreaOverlay(
        locationName: String?,
        coordinate: CLLocationCoordinate2D
    ) async -> PredictionAreaOverlay {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationName
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 10_000,
            longitudinalMeters: 10_000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()

            let nearest = nearestMapItem(to: coordinate, from: response.mapItems)
            if let nearest {
                let distanceMeters = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    .distance(from: nearest.location)
                let radiusKm = max(0.2, min(5.0, distanceMeters / 1000.0))
                return .circle(radiusKm: radiusKm)
            }
        } catch {
        }

        return .circle(radiusKm: 2.0)
    }

    private func nearestMapItem(
        to coordinate: CLLocationCoordinate2D,
        from items: [MKMapItem]
    ) -> MKMapItem? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return items.min { lhs, rhs in
            let left = CLLocation(latitude: lhs.location.coordinate.latitude, longitude: lhs.location.coordinate.longitude)
            let right = CLLocation(latitude: rhs.location.coordinate.latitude, longitude: rhs.location.coordinate.longitude)
            return target.distance(from: left) < target.distance(from: right)
        }
    }

    private func setupMap() {
        let center = CLLocationCoordinate2D(latitude: 20.0, longitude: 78.0)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 180))
        mapView.setRegion(region, animated: false)
    }
        
    private func setupCustomModal() {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let navVC = storyboard.instantiateViewController(withIdentifier: "PredictInputNavigationController") as? UINavigationController else { return }
        let screenHeight = view.frame.height
        let safeAreaTop = view.safeAreaInsets.top
        
        maxTopY = safeAreaTop + 140
        initialLoadY = screenHeight * 0.45
        minBottomY = screenHeight * 0.85
        modalContainerView = UIView()
        modalContainerView.backgroundColor = .clear
        modalContainerView.layer.cornerRadius = 24
        modalContainerView.layer.maskedCorners = [
            CACornerMask.layerMinXMinYCorner,
            CACornerMask.layerMaxXMinYCorner
        ]
            
        modalContainerView.layer.shadowColor = UIColor.black.cgColor
        modalContainerView.layer.shadowOpacity = 0.2
        modalContainerView.layer.shadowOffset = CGSize(width: 0, height: -4)
        modalContainerView.layer.shadowRadius = 10
        modalContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modalContainerView)
        addChild(navVC)
        modalContainerView.addSubview(navVC.view)
        currentChildVC = navVC
            
        navVC.view.translatesAutoresizingMaskIntoConstraints = false
        navVC.view.clipsToBounds = true
        navVC.view.layer.cornerRadius = 24
        navVC.view.layer.maskedCorners = [
            CACornerMask.layerMinXMinYCorner,
            CACornerMask.layerMaxXMinYCorner
        ]
            
        navVC.view.leadingAnchor.constraint(equalTo: modalContainerView.leadingAnchor).isActive = true
        navVC.view.trailingAnchor.constraint(equalTo: modalContainerView.trailingAnchor).isActive = true
        navVC.view.topAnchor.constraint(equalTo: modalContainerView.topAnchor).isActive = true
        navVC.view.bottomAnchor.constraint(equalTo: modalContainerView.bottomAnchor).isActive = true
        navVC.didMove(toParent: self)
            
        modalTopConstraint = modalContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: initialLoadY)
        modalTopConstraint.isActive = true
        modalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        modalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        modalContainerView.heightAnchor.constraint(equalToConstant: screenHeight).isActive = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        navVC.navigationBar.addGestureRecognizer(panGesture)
        notifyVisibleSheetHeightChanged()
    }

        @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: view)
            
            switch gesture.state {
            case .began:
                originalTopConstant = modalTopConstraint.constant
                
            case .changed:
                let newY = originalTopConstant + translation.y
                if newY < maxTopY {
                    modalTopConstraint.constant = maxTopY
                } else if newY > minBottomY {
                    modalTopConstraint.constant = minBottomY
                } else {
                    modalTopConstraint.constant = newY
                }
                
                view.layoutIfNeeded()
                notifyVisibleSheetHeightChanged()
                
            case .ended, .cancelled:
                break
                
            default:
                break
            }
        }
    
    @objc private func didTapRedoFromNavBar() {
        revertToInputScreen(with: currentOutputInputs)
    }
    
    func updateMapWithCurrentInputs(inputs: [PredictionInputData]) {
        updateMap(with: inputs, predictions: [], overlayMode: .inputRadius)
    }
        
    func navigateToOutput(
        inputs: [PredictionInputData],
        predictions: [FinalPredictionResult],
        useInputRadiusOverlay: Bool = false
    ) {
            
        currentOutputInputs = inputs
        currentOutputUsesInputRadiusOverlay = useInputRadiusOverlay
        let overlayMode: OverlayMode = useInputRadiusOverlay ? .inputRadius : .mapItemArea
        updateMap(with: inputs, predictions: predictions, overlayMode: overlayMode)
        
        // Add "Redo" button on the map view's navigation bar
        let redoButton = UIBarButtonItem(title: "Redo", style: .plain, target: self, action: #selector(didTapRedoFromNavBar))
        navigationItem.leftBarButtonItem = redoButton
        navigationItem.hidesBackButton = true
        
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let outputNavVC = storyboard.instantiateViewController(withIdentifier: "PredictOutputNavigationController") as? UINavigationController else {
            return
        }
        
        outputNavVC.view.layer.cornerRadius = 24
            outputNavVC.view.clipsToBounds = true
            outputNavVC.view.translatesAutoresizingMaskIntoConstraints = false
            outputNavVC.view.layer.maskedCorners = [
                CACornerMask.layerMinXMinYCorner,
                CACornerMask.layerMaxXMinYCorner
            ]

        guard let outputVC = outputNavVC.viewControllers.first as? PredictOutputViewController else {
            return
        }

        outputVC.predictions = predictions
        outputVC.inputData = inputs
        
        outputVC.onPageChanged = nil

        addChild(outputNavVC)
            
        transition(from: self.currentChildVC!, to: outputNavVC, duration: 0.3, options: .transitionCrossDissolve, animations: nil) { [weak self] success in
            if let originalNavVC = self?.currentChildVC as? UINavigationController,
               let panGesture = originalNavVC.navigationBar.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) {
                originalNavVC.navigationBar.removeGestureRecognizer(panGesture)
                outputNavVC.navigationBar.addGestureRecognizer(panGesture)
            }
            self?.currentChildVC?.removeFromParent()
            outputNavVC.didMove(toParent: self)
            self?.currentChildVC = outputNavVC
            outputNavVC.view.leadingAnchor.constraint(equalTo: (self?.modalContainerView.leadingAnchor)!).isActive = true
            outputNavVC.view.trailingAnchor.constraint(equalTo: (self?.modalContainerView.trailingAnchor)!).isActive = true
            outputNavVC.view.topAnchor.constraint(equalTo: (self?.modalContainerView.topAnchor)!).isActive = true
            outputNavVC.view.bottomAnchor.constraint(equalTo: (self?.modalContainerView.bottomAnchor)!).isActive = true
            
            if let pending = self?.pendingOutputPredictions,
               let outputVC = outputNavVC.topViewController as? PredictOutputViewController {
                self?.pendingOutputPredictions = nil
                outputVC.updatePredictions(pending)
            }
            self?.notifyVisibleSheetHeightChanged()
        }
    }

    func refreshOutputPredictions(_ predictions: [FinalPredictionResult]) {
        let overlayMode: OverlayMode = currentOutputUsesInputRadiusOverlay ? .inputRadius : .mapItemArea
        updateMap(with: currentOutputInputs, predictions: predictions, overlayMode: overlayMode)

        if let nav = currentChildVC as? UINavigationController,
           let outputVC = nav.topViewController as? PredictOutputViewController {
            outputVC.updatePredictions(predictions)
        } else {
            pendingOutputPredictions = predictions
        }
    }

    func revertToInputScreen(with inputs: [PredictionInputData]) {
        // Restore standard back button
        navigationItem.leftBarButtonItem = nil
        navigationItem.hidesBackButton = false
        
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let inputNavVC = storyboard.instantiateViewController(withIdentifier: "PredictInputNavigationController") as? UINavigationController,
              let inputVC = inputNavVC.viewControllers.first as? PredictInputViewController else {
            return
        }
        
        inputVC.inputData = inputs
        updateMap(with: inputs, predictions: [], overlayMode: .inputRadius)
        inputNavVC.view.layer.cornerRadius = 24
        inputNavVC.view.clipsToBounds = true
        inputNavVC.view.translatesAutoresizingMaskIntoConstraints = false
        inputNavVC.view.layer.maskedCorners = [
            CACornerMask.layerMinXMinYCorner,
            CACornerMask.layerMaxXMinYCorner
        ]
        addChild(inputNavVC)
        
        transition(from: self.currentChildVC!, to: inputNavVC, duration: 0.3, options: .transitionCrossDissolve, animations: nil) { [weak self] success in
            
            if let originalNavVC = self?.currentChildVC as? UINavigationController,
               let panGesture = originalNavVC.navigationBar.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) {
                
                originalNavVC.navigationBar.removeGestureRecognizer(panGesture)
                inputNavVC.navigationBar.addGestureRecognizer(panGesture)
            }
     
            self?.currentChildVC?.removeFromParent()
            inputNavVC.didMove(toParent: self)
            self?.currentChildVC = inputNavVC
            inputNavVC.view.leadingAnchor.constraint(equalTo: (self?.modalContainerView.leadingAnchor)!).isActive = true
            inputNavVC.view.trailingAnchor.constraint(equalTo: (self?.modalContainerView.trailingAnchor)!).isActive = true
            inputNavVC.view.topAnchor.constraint(equalTo: (self?.modalContainerView.topAnchor)!).isActive = true
            inputNavVC.view.bottomAnchor.constraint(equalTo: (self?.modalContainerView.bottomAnchor)!).isActive = true
            
            self?.notifyVisibleSheetHeightChanged()
        }
    }

    private func notifyVisibleSheetHeightChanged() {
        let visibleHeight = max(0, view.bounds.height - modalTopConstraint.constant)
        if let nav = currentChildVC as? UINavigationController,
           let top = nav.topViewController as? ModalSheetHeightAware {
            top.updateVisibleSheetHeight(visibleHeight)
        } else if let aware = currentChildVC as? ModalSheetHeightAware {
            aware.updateVisibleSheetHeight(visibleHeight)
        }
    }
 
    func filterMapForBird(_ prediction: FinalPredictionResult) {
        mapView.removeOverlays(currentGeoJSONOverlays)
        currentGeoJSONOverlays.removeAll()

        let coord = CLLocationCoordinate2D(
            latitude: prediction.matchedLocation.lat,
            longitude: prediction.matchedLocation.lon
        )

        if let speciesCode = prediction.ebirdSpeciesCode {
            Task {
                do {
                    let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
                    guard let geoJSONString = try await SkyTrailsAPIService.shared.fetchSpeciesRange(
                        ebirdSpeciesCode: speciesCode,
                        weekNumber: currentWeek
                    ) else { return }

                    guard let geoJSONData = geoJSONString.data(using: .utf8) else { return }
                    
                    let decoder = MKGeoJSONDecoder()
                    let objects = try decoder.decode(geoJSONData)
                    
                    await MainActor.run {
                        for object in objects {
                            if let feature = object as? MKGeoJSONFeature {
                                for geometry in feature.geometry {
                                    if let polygon = geometry as? MKPolygon {
                                        self.mapView.addOverlay(polygon)
                                        self.currentGeoJSONOverlays.append(polygon)
                                    } else if let multiPolygon = geometry as? MKMultiPolygon {
                                        self.mapView.addOverlay(multiPolygon)
                                        self.currentGeoJSONOverlays.append(multiPolygon)
                                    }
                                }
                            }
                        }
                        self.applyResultMapViewport(anchorCoordinates: [coord], animated: true)
                    }
                } catch {
                    await MainActor.run {
                        self.applyResultMapViewport(anchorCoordinates: [coord], animated: true)
                    }
                }
            }
        } else {
            applyResultMapViewport(anchorCoordinates: [coord], animated: true)
        }
    }

    private func applyResultMapViewport(
        anchorCoordinates: [CLLocationCoordinate2D],
        animated: Bool
    ) {
        guard mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }

        let targetMapRect = predictionAreaMapRect() ?? fallbackMapRect(from: anchorCoordinates)
        guard !targetMapRect.isNull, !targetMapRect.isEmpty else { return }

        let mapWidth = mapView.bounds.width
        let mapHeight = mapView.bounds.height
        let topHalfHeight = mapHeight * 0.5
        let targetWidth = mapWidth * 0.8
        let targetHeight = topHalfHeight * 0.8
        let leftRightPadding = max(8, (mapWidth - targetWidth) / 2.0)
        let topPadding = max(8, (topHalfHeight - targetHeight) / 2.0)
        let bottomPadding = max(8, mapHeight - topPadding - targetHeight)

        let edgeInsets = UIEdgeInsets(
            top: topPadding,
            left: leftRightPadding,
            bottom: bottomPadding,
            right: leftRightPadding
        )
        mapView.setVisibleMapRect(targetMapRect, edgePadding: edgeInsets, animated: animated)
    }

    private func predictionAreaMapRect() -> MKMapRect? {
        var combinedRect = MKMapRect.null
        for overlay in mapView.overlays {
            combinedRect = combinedRect.isNull ? overlay.boundingMapRect : combinedRect.union(overlay.boundingMapRect)
        }
        return combinedRect.isNull ? nil : combinedRect
    }

    private func fallbackMapRect(from coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        let validCoordinates = coordinates.filter { CLLocationCoordinate2DIsValid($0) }
        guard let first = validCoordinates.first else {
            return MKMapRect.null
        }

        var rect = MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 0, height: 0))
        for coordinate in validCoordinates.dropFirst() {
            let pointRect = MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize(width: 0, height: 0))
            rect = rect.union(pointRect)
        }
        if rect.size.width < 100 || rect.size.height < 100 {
            let centerPoint = MKMapPoint(first)
            let metersPerMapPoint = MKMetersPerMapPointAtLatitude(first.latitude)
            let mapPoints = 2500.0 / metersPerMapPoint
            rect = MKMapRect(
                x: centerPoint.x - mapPoints,
                y: centerPoint.y - mapPoints,
                width: mapPoints * 2,
                height: mapPoints * 2
            )
        }

        return rect
    }
    
}

extension PredictMapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let isBirdRange = currentGeoJSONOverlays.contains { $0 === overlay }
        
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            if isBirdRange {
                renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                renderer.lineWidth = 2.0
            } else {
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.75)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.10)
                renderer.lineWidth = 1.6
            }
            return renderer
        }
        
        if let multiPolygon = overlay as? MKMultiPolygon {
            let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
            if isBirdRange {
                renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                renderer.lineWidth = 2.0
            } else {
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.75)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.10)
                renderer.lineWidth = 1.6
            }
            return renderer
        }
        
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.08)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
            renderer.lineWidth = 1.5
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        
        guard annotation is PredictionAnnotation else { return nil }

        let identifier = "CenterPin"
        let markerView = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        markerView.annotation = annotation
        markerView.canShowCallout = false
        markerView.markerTintColor = .systemTeal
        markerView.glyphImage = UIImage(systemName: "mappin.and.ellipse")
        markerView.glyphText = nil
        markerView.glyphTintColor = .white
        markerView.titleVisibility = .hidden
        markerView.subtitleVisibility = .hidden
        markerView.transform = .identity
        markerView.alpha = 1.0
        markerView.zPriority = .max
        return markerView
    }
}
