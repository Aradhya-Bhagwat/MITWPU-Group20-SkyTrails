//
//  PredictMapViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit
import MapKit
import QuartzCore

class PredictMapViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    
    private var currentChildVC: UIViewController?
    private var modalContainerView: UIView!
    private var modalTopConstraint: NSLayoutConstraint!
    private var originalTopConstant: CGFloat = 0
    private var maxTopY: CGFloat = 120
    private var minBottomY: CGFloat = 0
    private var initialLoadY: CGFloat = 0
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMap()
        setupCustomModal()
        mapView.delegate = self
    }
        
    private func updateMap(with inputs: [PredictionInputData], predictions: [FinalPredictionResult]) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        var annotations: [MKAnnotation] = []
        var locationCoordinates: [CLLocationCoordinate2D] = []
        
        for input in inputs {
            guard let lat = input.latitude,
                  let lon = input.longitude else { continue }
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            locationCoordinates.append(coordinate)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = input.locationName ?? "Search Location"
            annotations.append(annotation)
            let circle = MKCircle(center: coordinate, radius: Double(input.areaValue * 1000))
            mapView.addOverlay(circle)
        }
        
        for prediction in predictions {
            let coord = CLLocationCoordinate2D(latitude: prediction.matchedLocation.lat, longitude: prediction.matchedLocation.lon)
            let birdPin = MKPointAnnotation()
            birdPin.coordinate = coord
            birdPin.title = prediction.birdName
            birdPin.subtitle = "Predicted near \(inputs[prediction.matchedInputIndex].locationName ?? "input")"
            annotations.append(birdPin)
            locationCoordinates.append(coord)
        }
        
        mapView.addAnnotations(annotations)
        if let firstInput = inputs.first,
           let lat = firstInput.latitude,
           let lon = firstInput.longitude {
            
            let centerCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let radiusInMeters = Double(firstInput.areaValue * 1000)
            let visibleMapWidthInMeters = (radiusInMeters * 2) / 0.50
            let aspectRatio = mapView.bounds.height / mapView.bounds.width
            let visibleMapHeightInMeters = visibleMapWidthInMeters * Double(aspectRatio)
            let verticalOffsetInMeters = visibleMapHeightInMeters / 3.0
            let metersPerDegreeLatitude = 111111.0
            let latitudeOffset = verticalOffsetInMeters / metersPerDegreeLatitude
            let newCenterLatitude = centerCoord.latitude - latitudeOffset
            let newCenter = CLLocationCoordinate2D(latitude: newCenterLatitude, longitude: centerCoord.longitude)
            let region = MKCoordinateRegion(center: newCenter, latitudinalMeters: visibleMapHeightInMeters, longitudinalMeters: visibleMapWidthInMeters)
            mapView.setRegion(region, animated: true)
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
                
            case .ended, .cancelled:
                break
                
            default:
                break
            }
        }
    
    func updateMapWithCurrentInputs(inputs: [PredictionInputData]) {
        updateMap(with: inputs, predictions: [])
    }
        
    func navigateToOutput(inputs: [PredictionInputData], predictions: [FinalPredictionResult]) {
            
        updateMap(with: inputs, predictions: predictions)
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
        }
    }

    func revertToInputScreen(with inputs: [PredictionInputData]) {
        
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let inputNavVC = storyboard.instantiateViewController(withIdentifier: "PredictInputNavigationController") as? UINavigationController,
              let inputVC = inputNavVC.viewControllers.first as? PredictInputViewController else {
            return
        }
        
        inputVC.inputData = inputs
        updateMap(with: inputs, predictions: [])
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
        }
    }
 
    func filterMapForBird(_ prediction: FinalPredictionResult) {
        let birdAnnotations = mapView.annotations.filter { annotation in
            if let subtitle = annotation.subtitle, subtitle?.contains("Predicted near") == true {
                return true
            }
            return false
        }
        mapView.removeAnnotations(birdAnnotations)
        let coord = CLLocationCoordinate2D(latitude: prediction.matchedLocation.lat, longitude: prediction.matchedLocation.lon)
        let birdPin = MKPointAnnotation()
        birdPin.coordinate = coord
        birdPin.title = prediction.birdName
        birdPin.subtitle = "Predicted near location"
        mapView.addAnnotation(birdPin)
        let latitudinalMeters: Double = 10000
        let longitudinalMeters: Double = 10000
        let verticalOffsetInMeters = latitudinalMeters / 3.0
        let metersPerDegreeLatitude = 111111.0
        let latitudeOffset = verticalOffsetInMeters / metersPerDegreeLatitude
        let newCenterLatitude = coord.latitude - latitudeOffset
        let newCenter = CLLocationCoordinate2D(latitude: newCenterLatitude, longitude: coord.longitude)
        let region = MKCoordinateRegion(center: newCenter, latitudinalMeters: latitudinalMeters, longitudinalMeters: longitudinalMeters)
        mapView.setRegion(region, animated: true)
    }
    
    private func colorFor(name: String) -> UIColor {
        var hash = 0
        for char in name {
            let val = Int(char.asciiValue ?? 0)
            hash = val &+ ((hash &<< 5) &- hash)
        }
        let color = UIColor(
            red: CGFloat((hash >> 16) & 0xFF) / 255.0,
            green: CGFloat((hash >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hash & 0xFF) / 255.0,
            alpha: 1.0
        )
        return color
    }
}

extension PredictMapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5)
            renderer.lineWidth = 1
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        
        let identifier = "PredictionPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        if let markerView = annotationView as? MKMarkerAnnotationView {
            
            let isPredictedBird = annotation.subtitle??.contains("Predicted near") ?? false
            
            if isPredictedBird {
                let birdName = annotation.title ?? ""
                markerView.markerTintColor = colorFor(name: birdName ?? "Bird")
                markerView.glyphImage = UIImage(systemName: "feather")
            } else {
                markerView.markerTintColor = .systemBlue
                markerView.glyphImage = UIImage(systemName: "magnifyingglass")
            }
        }
        
        return annotationView
    }
}
