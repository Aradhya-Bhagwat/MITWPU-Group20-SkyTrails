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
        
        // Drag State Variables
        private var originalTopConstant: CGFloat = 0
        
        // Limits & Positions
        private var maxTopY: CGFloat = 120    // Ceiling
        private var minBottomY: CGFloat = 0   // Floor (The 1/10th mark)
        private var initialLoadY: CGFloat = 0 // Start Position (The 2/5th mark)
        
        override func viewDidLoad() {
            super.viewDidLoad()
            setupMap()
            setupCustomModal()
            mapView.delegate = self
        }
    private func updateMap(with inputs: [PredictionInputData], predictions: [FinalPredictionResult]) {
        // 1. Clear existing annotations/overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        var annotations: [MKAnnotation] = []
        var overlays: [MKOverlay] = []
        
        for input in inputs {
            guard let lat = input.latitude,
                  let lon = input.longitude else { continue }
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            // A. Add Pin (Annotation) for user's input location
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = input.locationName ?? "Search Location"
            annotations.append(annotation)
            
            // B. Add Circle (Overlay) for the area
            // MKCircle requires radius in meters
            let circle = MKCircle(center: coordinate, radius: Double(input.areaValue * 1000))
            overlays.append(circle)
        }
        
        // C. Add Bird Pins (optional, using the matched sighting coordinates)
        for prediction in predictions {
            let coord = CLLocationCoordinate2D(latitude: prediction.matchedLocation.lat, longitude: prediction.matchedLocation.lon)
            let birdPin = MKPointAnnotation()
            birdPin.coordinate = coord
            birdPin.title = prediction.birdName // Title of the bird
            birdPin.subtitle = "Predicted near \(inputs[prediction.matchedInputIndex].locationName ?? "input")"
            annotations.append(birdPin)
        }

        mapView.addAnnotations(annotations)
        mapView.addOverlays(overlays)
        
        // Optional: Zoom map to fit all new pins/circles
        if let firstInput = inputs.first,
           let lat = firstInput.latitude,
           let lon = firstInput.longitude {
            let firstCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = MKCoordinateRegion(center: firstCoord, latitudinalMeters: 50000, longitudinalMeters: 50000)
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
            
            // 1. Calculate Limits
            let screenHeight = view.frame.height
            let safeAreaTop = view.safeAreaInsets.top
            
            // --- CALCULATION UPDATES ---
            
            // A. Ceiling: Safe area + 140
            maxTopY = safeAreaTop + 140
            
            // B. Initial Position: Occupy 2/5 of screen
            // Meaning: Top edge is 3/5 (60%) down the screen
            initialLoadY = screenHeight * 0.60
            
            // C. The Floor: Occupy 1/10 of screen
            // Meaning: Top edge is 9/10 (90%) down the screen
            minBottomY = screenHeight * 0.80
            
            // ---------------------------
            
            // 2. Setup Container
            modalContainerView = UIView()
            modalContainerView.backgroundColor = .clear
            modalContainerView.layer.cornerRadius = 24
            modalContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            
            // Shadows
            modalContainerView.layer.shadowColor = UIColor.black.cgColor
            modalContainerView.layer.shadowOpacity = 0.2
            modalContainerView.layer.shadowOffset = CGSize(width: 0, height: -4)
            modalContainerView.layer.shadowRadius = 10
            
            
            modalContainerView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(modalContainerView)
            
            // 3. Embed Child VC
            addChild(navVC)
            modalContainerView.addSubview(navVC.view)
            navVC.view.translatesAutoresizingMaskIntoConstraints = false
            navVC.view.layer.cornerRadius = 24
            navVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            navVC.view.clipsToBounds = true
            
            NSLayoutConstraint.activate([
                navVC.view.leadingAnchor.constraint(equalTo: modalContainerView.leadingAnchor),
                navVC.view.trailingAnchor.constraint(equalTo: modalContainerView.trailingAnchor),
                navVC.view.topAnchor.constraint(equalTo: modalContainerView.topAnchor),
                navVC.view.bottomAnchor.constraint(equalTo: modalContainerView.bottomAnchor)
            ])
            navVC.didMove(toParent: self)
            
            // 4. MAIN CONSTRAINTS
            // ⭐️ Start at `initialLoadY` (2/5ths visible), not `minBottomY`
            modalTopConstraint = modalContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: initialLoadY)
            
            NSLayoutConstraint.activate([
                modalTopConstraint,
                modalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                modalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                modalContainerView.heightAnchor.constraint(equalToConstant: screenHeight)
            ])
            
            // 5. Add Pan Gesture
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            navVC.navigationBar.addGestureRecognizer(panGesture)
        }
        
        // MARK: - Absolute Drag Logic
        
        @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: view)
            
            switch gesture.state {
            case .began:
                originalTopConstant = modalTopConstraint.constant
                
            case .changed:
                let newY = originalTopConstant + translation.y
                
                // Apply Limits (Clamp)
                if newY < maxTopY {
                    // Hit the Ceiling
                    modalTopConstraint.constant = maxTopY
                } else if newY > minBottomY {
                    // Hit the Floor (Now the 1/10th mark)
                    modalTopConstraint.constant = minBottomY
                } else {
                    // Free Movement (Between 1/10th and Ceiling)
                    modalTopConstraint.constant = newY
                }
                
                view.layoutIfNeeded()
                
            case .ended, .cancelled:
                // Still "Stay Put" logic (no snapping)
                break
                
            default:
                break
            }
        }
    func navigateToOutput(inputs: [PredictionInputData], predictions: [FinalPredictionResult]) {
        
        // 1. Update the Map Visualization immediately
        updateMap(with: inputs, predictions: predictions)
        
        // 2. Instantiate the Output VC
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let outputVC = storyboard.instantiateViewController(withIdentifier: "PredictOutputViewController") as? PredictOutputViewController,
              let currentVC = currentChildVC,
              let container = modalContainerView else {
            print("❌ Could not find PredictOutputViewController or current child.")
            return
        }
        
        // 3. Pass data to the Output VC
        // ⭐️ You will need to define these properties in PredictOutputViewController
        outputVC.predictions = predictions
        outputVC.inputData = inputs
        
        // 4. Prepare for transition (using existing transition logic)
        outputVC.view.frame = container.bounds
        outputVC.view.layer.cornerRadius = 24
        outputVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        outputVC.view.clipsToBounds = true
        outputVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        // 5. Execute Transition
        addChild(outputVC)
        
        transition(from: currentVC, to: outputVC, duration: 0.3, options: .transitionCrossDissolve, animations: nil) { [weak self] success in
            
            // 6. Cleanup & Pin New View
            currentVC.removeFromParent()
            outputVC.didMove(toParent: self)
            self?.currentChildVC = outputVC
            
            NSLayoutConstraint.activate([
                outputVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                outputVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                outputVC.view.topAnchor.constraint(equalTo: container.topAnchor),
                outputVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
    }
    
    
    }
extension PredictMapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let circleRenderer = MKCircleRenderer(circle: circleOverlay)
            circleRenderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
            circleRenderer.lineWidth = 2
            circleRenderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1) // Light fill color
            return circleRenderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // We can skip MKUserLocation if we don't want to customize it
        guard !(annotation is MKUserLocation) else { return nil }
        
        let identifier = "CustomAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        // ⭐️ Optional: Customize appearance based on whether it's an input pin or a bird pin
        // if let birdAnnotation = annotation as? BirdAnnotation { // Requires a custom class
        //     // annotationView?.image = UIImage(named: birdAnnotation.imageName)
        // }
        
        return annotationView
    }
}
