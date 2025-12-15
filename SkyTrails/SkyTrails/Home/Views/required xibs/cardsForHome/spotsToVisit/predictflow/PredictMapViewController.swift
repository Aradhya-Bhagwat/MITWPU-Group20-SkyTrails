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
        
        // MARK: - Map Update Logic
        
    private func updateMap(with inputs: [PredictionInputData], predictions: [FinalPredictionResult]) {
        // 1. Clear existing annotations/overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        print("\n--- DEBUG: Map Update Triggered ---\n")
        
        var annotations: [MKAnnotation] = []
        var locationCoordinates: [CLLocationCoordinate2D] = [] // Used for zooming
        
        for input in inputs {
            guard let lat = input.latitude,
                  let lon = input.longitude else { continue }
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            locationCoordinates.append(coordinate)
            
            // A. Add Pin (Annotation) for user's input location
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = input.locationName ?? "Search Location"
            annotations.append(annotation)
            
            // B. Add Circle (Overlay) for the area
            let circle = MKCircle(center: coordinate, radius: Double(input.areaValue * 1000))
            mapView.addOverlay(circle)
        }
        
        // C. Add Bird Pins (using the matched sighting coordinates)
        for prediction in predictions {
            let coord = CLLocationCoordinate2D(latitude: prediction.matchedLocation.lat, longitude: prediction.matchedLocation.lon)
            let birdPin = MKPointAnnotation()
            birdPin.coordinate = coord
            birdPin.title = prediction.birdName // Title of the bird
            birdPin.subtitle = "Predicted near \(inputs[prediction.matchedInputIndex].locationName ?? "input")"
            annotations.append(birdPin)
            locationCoordinates.append(coord) // Include bird sightings in zoom calculation
        }
        
        mapView.addAnnotations(annotations)
        
        // 2. Zoom map to fit all new pins/circles
        if !locationCoordinates.isEmpty {
            
            // Calculate region containing all points
            let mapRect = locationCoordinates.reduce(MKMapRect.null) { (mapRect, coordinate) -> MKMapRect in
                let point = MKMapPoint(coordinate)
                let rect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                return mapRect.union(rect)
            }
            
            
            // Fit the calculated mapRect with padding
            let padding: CGFloat = 40
            mapView.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding), animated: true)
        }
        
        //  mapView.addAnnotations(annotations)
          // mapView.addOverlays(overlays)
        
        // Optional: Zoom map to fit all new pins/circles
                if let firstInput = inputs.first,
                   let lat = firstInput.latitude,
                   let lon = firstInput.longitude {
                    let firstCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let region = MKCoordinateRegion(center: firstCoord, latitudinalMeters: 50000, longitudinalMeters: 50000)
                    mapView.setRegion(region, animated: true)
        
                }
        
        // MARK: - Setup Methods
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
            
            maxTopY = safeAreaTop + 140
            initialLoadY = screenHeight * 0.45
            minBottomY = screenHeight * 0.90 // Changed from 0.80 back to 0.90 for 1/10th visibility
            
            // ---------------------------
            
            // 2. Setup Container
            modalContainerView = UIView()
            modalContainerView.backgroundColor = .clear
            modalContainerView.layer.cornerRadius = 24
            
            // ✅ FIX 2: Use CACornerMask prefix for contextual type
            modalContainerView.layer.maskedCorners = [
                CACornerMask.layerMinXMinYCorner,
                CACornerMask.layerMaxXMinYCorner
            ]
            
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
            
            // ⭐️ Save the initial child reference
            currentChildVC = navVC
            
            
            navVC.view.translatesAutoresizingMaskIntoConstraints = false
            navVC.view.clipsToBounds = true
            navVC.view.layer.cornerRadius = 24
            
            // ✅ FIX 2: Use CACornerMask prefix for contextual type
            navVC.view.layer.maskedCorners = [
                CACornerMask.layerMinXMinYCorner,
                CACornerMask.layerMaxXMinYCorner
            ]
            
    
            
            NSLayoutConstraint.activate([
                navVC.view.leadingAnchor.constraint(equalTo: modalContainerView.leadingAnchor),
                navVC.view.trailingAnchor.constraint(equalTo: modalContainerView.trailingAnchor),
                navVC.view.topAnchor.constraint(equalTo: modalContainerView.topAnchor),
                navVC.view.bottomAnchor.constraint(equalTo: modalContainerView.bottomAnchor)
            ])
            navVC.didMove(toParent: self)
            
            // 4. MAIN CONSTRAINTS
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
        
        // MARK: - Drag Logic
        
        @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: view)
            
            switch gesture.state {
            case .began:
                originalTopConstant = modalTopConstraint.constant
                
            case .changed:
                let newY = originalTopConstant + translation.y
                
                // Apply Limits (Clamp)
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
    // In PredictMapViewController.swift, inside the PredictMapViewController class:

    func updateMapWithCurrentInputs(inputs: [PredictionInputData]) {
        // ⭐️ CALL THE MAIN MAP LOGIC, but pass empty predictions
        // since the user is still on the input screen.
        updateMap(with: inputs, predictions: [])
    }
        
        // MARK: - Navigation Logic
        
    // NEW function signature
    // ORIGINAL function signature
    func navigateToOutput(inputs: [PredictionInputData], predictions: [FinalPredictionResult]) {
                
        // ⭐️ FIX: Call updateMap here to show final pins/circles before transition
        updateMap(with: inputs, predictions: predictions)
        
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
            
        // ⭐️ Step 1: Instantiate the Navigation Controller wrapper
        guard let outputNavVC = storyboard.instantiateViewController(withIdentifier: "PredictOutputNavigationController") as? UINavigationController else {
            print("❌ Could not find PredictOutputNavigationController.")
            return
        }
        
        outputNavVC.view.layer.cornerRadius = 24
            outputNavVC.view.clipsToBounds = true
            outputNavVC.view.translatesAutoresizingMaskIntoConstraints = false // Necessary for the pinning constraints
            outputNavVC.view.layer.maskedCorners = [
                CACornerMask.layerMinXMinYCorner,
                CACornerMask.layerMaxXMinYCorner
            ]

        // ⭐️ Step 2: Extract the root PredictOutputViewController
        guard let outputVC = outputNavVC.viewControllers.first as? PredictOutputViewController,
              let currentVC = currentChildVC,
              let container = modalContainerView else {
            print("❌ Error: Internal state failure or could not extract root VC.")
            return
        }

        // Pass data to the extracted root VC
        outputVC.predictions = predictions
        outputVC.inputData = inputs
            
        // ⭐️ Use the Navigation Controller for the transition and pinning
        addChild(outputNavVC) // Use the wrapper
            
        transition(from: currentVC, to: outputNavVC, duration: 0.3, options: .transitionCrossDissolve, animations: nil) { [weak self] success in
            
            // --- ⭐️ DRAG GESTURE TRANSFER FIX ⭐️ ---
            if let originalNavVC = currentVC as? UINavigationController,
               let panGesture = originalNavVC.navigationBar.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) {
                
                // 1. Remove the gesture from the old navigation bar
                originalNavVC.navigationBar.removeGestureRecognizer(panGesture)
                
                // 2. Add the SAME gesture to the new output navigation bar
                outputNavVC.navigationBar.addGestureRecognizer(panGesture)
            }
            // ----------------------------------------
            
            // Cleanup and Pinning
            currentVC.removeFromParent()
            outputNavVC.didMove(toParent: self)
            self?.currentChildVC = outputNavVC // currentChildVC must now hold the Nav Controller
            
            // Pin the Navigation Controller's view
            NSLayoutConstraint.activate([
                outputNavVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                outputNavVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                outputNavVC.view.topAnchor.constraint(equalTo: container.topAnchor),
                outputNavVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
    }
    
    // In PredictMapViewController.swift (inside the class definition)

    func revertToInputScreen(with inputs: [PredictionInputData]) {
        
        // 1. Instantiate the Predict Input Navigation Controller
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let inputNavVC = storyboard.instantiateViewController(withIdentifier: "PredictInputNavigationController") as? UINavigationController,
              let inputVC = inputNavVC.viewControllers.first as? PredictInputViewController,
              let currentVC = currentChildVC,
              let container = modalContainerView else {
            print("❌ Could not instantiate PredictInputNavigationController for Revert.")
            return
        }
        
        // 2. Load the retained data back into the Input VC
        inputVC.inputData = inputs // ⭐️ This retains all the user's previously entered data
        
        // 3. Update the map to clear predictions and only show input pins/circles
        updateMap(with: inputs, predictions: [])
        
        // 4. Set up the input VC view
        inputNavVC.view.layer.cornerRadius = 24
        inputNavVC.view.clipsToBounds = true
        inputNavVC.view.translatesAutoresizingMaskIntoConstraints = false
        inputNavVC.view.layer.maskedCorners = [
            CACornerMask.layerMinXMinYCorner,
            CACornerMask.layerMaxXMinYCorner
        ]
        
        // 5. Execute Reverse Transition
        addChild(inputNavVC)
        
        transition(from: currentVC, to: inputNavVC, duration: 0.3, options: .transitionCrossDissolve, animations: nil) { [weak self] success in
            
            // --- DRAG GESTURE TRANSFER FIX (Must be repeated for reverse transition) ---
            if let originalNavVC = currentVC as? UINavigationController,
               let panGesture = originalNavVC.navigationBar.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) {
                
                originalNavVC.navigationBar.removeGestureRecognizer(panGesture)
                inputNavVC.navigationBar.addGestureRecognizer(panGesture) // Transfer back to Input VC
            }
            // ------------------------------------------------------------------------
            
            // Cleanup and Pinning
            currentVC.removeFromParent()
            inputNavVC.didMove(toParent: self)
            self?.currentChildVC = inputNavVC // currentChildVC now holds the Input VC
            
            // Pin the Navigation Controller's view
            NSLayoutConstraint.activate([
                inputNavVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                inputNavVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                inputNavVC.view.topAnchor.constraint(equalTo: container.topAnchor),
                inputNavVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
    }
    }


// MARK: - MKMapViewDelegate
extension PredictMapViewController: MKMapViewDelegate {
    
    // ... (mapView(_:rendererFor:) remains unchanged)
    
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
            
            // ⭐️ FIX: Safely check the optional subtitle using optional chaining and nil-coalescing.
            let isPredictedBird = annotation.subtitle??.contains("Predicted near") ?? false
            
            if isPredictedBird {
                // Pin for a Bird Sighting (Prediction Result)
                markerView.markerTintColor = .systemGreen
                markerView.glyphImage = UIImage(systemName: "feather")
            } else {
                // Pin for User Input Location
                markerView.markerTintColor = .systemBlue
                markerView.glyphImage = UIImage(systemName: "magnifyingglass")
            }
        }
        
        return annotationView
    }
}
