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
        
        // 2. Zoom map to fit the circle (10% of screen width) and position it in the top 1/3
        if let firstInput = inputs.first,
           let lat = firstInput.latitude,
           let lon = firstInput.longitude {
            
            let centerCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let radiusInMeters = Double(firstInput.areaValue * 1000)
            
            // A. Calculate visible map width so circle is 50% of screen width
            // If circle (diameter = 2*r) is 50% of width, then total width = (2*r) / 0.50
            let visibleMapWidthInMeters = (radiusInMeters * 2) / 0.50
            
            // B. Calculate visible map height based on aspect ratio
            let aspectRatio = mapView.bounds.height / mapView.bounds.width
            let visibleMapHeightInMeters = visibleMapWidthInMeters * Double(aspectRatio)
            
            // C. Offset the center to position circle in top 1/3
            // To move the target UP on screen, we move the map center DOWN (lower latitude)
            // Top 1/3 means center is at 1/6 from top. Screen center is at 3/6.
            // Difference is 2/6 = 1/3 of screen height.
            let verticalOffsetInMeters = visibleMapHeightInMeters / 3.0 // Move center down by 1/3 screen height
            
            // Convert meters to latitude degrees (approx 111,111 meters per degree)
            let metersPerDegreeLatitude = 111111.0
            let latitudeOffset = verticalOffsetInMeters / metersPerDegreeLatitude
            
            let newCenterLatitude = centerCoord.latitude - latitudeOffset
            let newCenter = CLLocationCoordinate2D(latitude: newCenterLatitude, longitude: centerCoord.longitude)
            
            // D. Set the Region
            let region = MKCoordinateRegion(center: newCenter, latitudinalMeters: visibleMapHeightInMeters, longitudinalMeters: visibleMapWidthInMeters)
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
        guard let outputVC = outputNavVC.viewControllers.first as? PredictOutputViewController else {
            return
        }


        // Pass data to the extracted root VC
        outputVC.predictions = predictions
        outputVC.inputData = inputs
            
        // ⭐️ Use the Navigation Controller for the transition and pinning
        addChild(outputNavVC) // Use the wrapper
            
        transition(from: self.currentChildVC!, to: outputNavVC, duration: 0.3, options: .transitionCrossDissolve, animations: nil) { [weak self] success in
            
            // --- ⭐️ DRAG GESTURE TRANSFER FIX ⭐️ ---
            if let originalNavVC = self?.currentChildVC as? UINavigationController,
               let panGesture = originalNavVC.navigationBar.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) {
                
                // 1. Remove the gesture from the old navigation bar
                originalNavVC.navigationBar.removeGestureRecognizer(panGesture)
                
                // 2. Add the SAME gesture to the new output navigation bar
                outputNavVC.navigationBar.addGestureRecognizer(panGesture)
            }
            // ----------------------------------------
            
            // Cleanup and Pinning
            self?.currentChildVC?.removeFromParent()
            outputNavVC.didMove(toParent: self)
            self?.currentChildVC = outputNavVC // currentChildVC must now hold the Nav Controller
            
            // Pin the Navigation Controller's view
            NSLayoutConstraint.activate([
                outputNavVC.view.leadingAnchor.constraint(equalTo: (self?.modalContainerView.leadingAnchor)!),
                outputNavVC.view.trailingAnchor.constraint(equalTo: (self?.modalContainerView.trailingAnchor)!),
                outputNavVC.view.topAnchor.constraint(equalTo: (self?.modalContainerView.topAnchor)!),
                outputNavVC.view.bottomAnchor.constraint(equalTo: (self?.modalContainerView.bottomAnchor)!)
            ])
        }
    }
    
    // In PredictMapViewController.swift (inside the class definition)

    func revertToInputScreen(with inputs: [PredictionInputData]) {
        
        // 1. Instantiate the Predict Input Navigation Controller
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let inputNavVC = storyboard.instantiateViewController(withIdentifier: "PredictInputNavigationController") as? UINavigationController,
              let inputVC = inputNavVC.viewControllers.first as? PredictInputViewController else {
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
        
        transition(from: self.currentChildVC!, to: inputNavVC, duration: 0.3, options: .transitionCrossDissolve, animations: nil) { [weak self] success in
            
            // --- DRAG GESTURE TRANSFER FIX (Must be repeated for reverse transition) ---
            if let originalNavVC = self?.currentChildVC as? UINavigationController,
               let panGesture = originalNavVC.navigationBar.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) {
                
                originalNavVC.navigationBar.removeGestureRecognizer(panGesture)
                inputNavVC.navigationBar.addGestureRecognizer(panGesture) // Transfer back to Input VC
            }
            // ------------------------------------------------------------------------
            
            // Cleanup and Pinning
            self?.currentChildVC?.removeFromParent()
            inputNavVC.didMove(toParent: self)
            self?.currentChildVC = inputNavVC // currentChildVC now holds the Input VC
            
            // Pin the Navigation Controller's view
            NSLayoutConstraint.activate([
                inputNavVC.view.leadingAnchor.constraint(equalTo: (self?.modalContainerView.leadingAnchor)!),
                inputNavVC.view.trailingAnchor.constraint(equalTo: (self?.modalContainerView.trailingAnchor)!),
                inputNavVC.view.topAnchor.constraint(equalTo: (self?.modalContainerView.topAnchor)!),
                inputNavVC.view.bottomAnchor.constraint(equalTo: (self?.modalContainerView.bottomAnchor)!)
            ])
        }
    }
    // MARK: - Bird Selection Logic
    func filterMapForBird(_ prediction: FinalPredictionResult) {
        // 1. Remove ONLY bird annotations (keep user location pins)
        let birdAnnotations = mapView.annotations.filter { annotation in
            // Identify bird pins by their subtitle (as set in updateMap) or if they are NOT the user location
            // Easier: Identify user location pins by title == input.locationName?
            // Or assume anything with "Predicted near" subtitle is a bird.
            if let subtitle = annotation.subtitle, subtitle?.contains("Predicted near") == true {
                return true
            }
            return false
        }
        mapView.removeAnnotations(birdAnnotations)
        
        // 2. Add the SINGLE selected bird pin
        let coord = CLLocationCoordinate2D(latitude: prediction.matchedLocation.lat, longitude: prediction.matchedLocation.lon)
        let birdPin = MKPointAnnotation()
        birdPin.coordinate = coord
        birdPin.title = prediction.birdName
        birdPin.subtitle = "Predicted near location" 
        
        mapView.addAnnotation(birdPin)
        
        // 3. Zoom to it and position in Top 1/3
        let latitudinalMeters: Double = 10000 // 10km span
        let longitudinalMeters: Double = 10000
        
        // Calculate offset to move target to top 1/3
        // We want the pin at 1/6 from top (Top 1/3 center). Map center is at 3/6.
        // Shift map center DOWN by 2/6 = 1/3 of visible height.
        let verticalOffsetInMeters = latitudinalMeters / 3.0
        let metersPerDegreeLatitude = 111111.0
        let latitudeOffset = verticalOffsetInMeters / metersPerDegreeLatitude
        
        let newCenterLatitude = coord.latitude - latitudeOffset
        let newCenter = CLLocationCoordinate2D(latitude: newCenterLatitude, longitude: coord.longitude)
        
        let region = MKCoordinateRegion(center: newCenter, latitudinalMeters: latitudinalMeters, longitudinalMeters: longitudinalMeters)
        mapView.setRegion(region, animated: true)
    }
    
    // Helper to generate consistent color from string
    private func colorFor(name: String) -> UIColor {
        var hash = 0
        for char in name {
            // Use wrapping arithmetic (&+, &-, &<<) to prevent overflow crash
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


// MARK: - MKMapViewDelegate
extension PredictMapViewController: MKMapViewDelegate {
    
    // Renderer for Overlays (Circles)
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2) // Translucent Blue
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5) // Slightly darker border
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
            
            // ⭐️ FIX: Safely check the optional subtitle using optional chaining and nil-coalescing.
            let isPredictedBird = annotation.subtitle??.contains("Predicted near") ?? false
            
            if isPredictedBird {
                // Pin for a Bird Sighting (Prediction Result)
                // ⭐️ FIX: Dynamic Color based on Title (Bird Name)
                let birdName = annotation.title ?? ""
                markerView.markerTintColor = colorFor(name: birdName ?? "Bird")
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
