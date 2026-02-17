//
//  WatchlistLocationRuleMapViewController.swift
//  SkyTrails
//
//  View controller for selecting location and radius for watchlist location rules
//

import UIKit
import MapKit
import CoreLocation

protocol WatchlistLocationRuleDelegate: AnyObject {
    func didSelectLocationRule(location: CLLocationCoordinate2D, radiusKm: Double, displayName: String)
}

@MainActor
class WatchlistLocationRuleMapViewController: UIViewController {
    
    // MARK: - UI Components
    private let mapView = MKMapView()
    private let searchContainerView = UIView()
    private let searchBar = UISearchBar()
    private let resultsTableView = UITableView()
    private let sliderContainerView = UIView()
    private let radiusSlider = UISlider()
    private let radiusLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    
    // MARK: - Properties
    weak var delegate: WatchlistLocationRuleDelegate?
    private let completer = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []
    private var selectedCoordinate: CLLocationCoordinate2D?
    private var radiusCircle: MKCircle?
    private var radiusAnnotation: MKPointAnnotation?
    
    // Default radius: 50km, range: 1-500km
    private var currentRadiusKm: Double = 50.0 {
        didSet {
            updateRadiusDisplay()
            updateRadiusCircle()
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMap()
        setupSearch()
        setupSlider()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Select Location & Radius"
        view.backgroundColor = .systemBackground
        
        // Search Container
        searchContainerView.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.backgroundColor = .systemBackground
        searchContainerView.layer.cornerRadius = 12
        searchContainerView.layer.shadowColor = UIColor.black.cgColor
        searchContainerView.layer.shadowOpacity = 0.1
        searchContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchContainerView.layer.shadowRadius = 4
        view.addSubview(searchContainerView)
        
        // Search Bar
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search for a location"
        searchBar.searchBarStyle = .minimal
        searchContainerView.addSubview(searchBar)
        
        // Map View
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        view.addSubview(mapView)
        
        // Results Table
        resultsTableView.translatesAutoresizingMaskIntoConstraints = false
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ResultCell")
        resultsTableView.isHidden = true
        resultsTableView.layer.cornerRadius = 12
        resultsTableView.layer.masksToBounds = true
        resultsTableView.backgroundColor = .systemBackground
        view.addSubview(resultsTableView)
        
        // Slider Container
        sliderContainerView.translatesAutoresizingMaskIntoConstraints = false
        sliderContainerView.backgroundColor = .systemBackground
        sliderContainerView.layer.cornerRadius = 16
        sliderContainerView.layer.shadowColor = UIColor.black.cgColor
        sliderContainerView.layer.shadowOpacity = 0.1
        sliderContainerView.layer.shadowOffset = CGSize(width: 0, height: -2)
        sliderContainerView.layer.shadowRadius = 4
        view.addSubview(sliderContainerView)
        
        // Radius Label
        radiusLabel.translatesAutoresizingMaskIntoConstraints = false
        radiusLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        radiusLabel.textAlignment = .center
        sliderContainerView.addSubview(radiusLabel)
        
        // Radius Slider
        radiusSlider.translatesAutoresizingMaskIntoConstraints = false
        radiusSlider.minimumValue = 1
        radiusSlider.maximumValue = 500
        radiusSlider.value = Float(currentRadiusKm)
        radiusSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        sliderContainerView.addSubview(radiusSlider)
        
        // Done Button
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.backgroundColor = .systemBlue
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.layer.cornerRadius = 12
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.isEnabled = false
        doneButton.alpha = 0.5
        sliderContainerView.addSubview(doneButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Search Container
            searchContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainerView.heightAnchor.constraint(equalToConstant: 50),
            
            // Search Bar
            searchBar.topAnchor.constraint(equalTo: searchContainerView.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -8),
            searchBar.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor),
            
            // Map View
            mapView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 8),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: sliderContainerView.topAnchor),
            
            // Results Table
            resultsTableView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 8),
            resultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultsTableView.heightAnchor.constraint(equalToConstant: 200),
            
            // Slider Container
            sliderContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sliderContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sliderContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sliderContainerView.heightAnchor.constraint(equalToConstant: 180),
            
            // Radius Label
            radiusLabel.topAnchor.constraint(equalTo: sliderContainerView.topAnchor, constant: 16),
            radiusLabel.leadingAnchor.constraint(equalTo: sliderContainerView.leadingAnchor, constant: 16),
            radiusLabel.trailingAnchor.constraint(equalTo: sliderContainerView.trailingAnchor, constant: -16),
            
            // Radius Slider
            radiusSlider.topAnchor.constraint(equalTo: radiusLabel.bottomAnchor, constant: 12),
            radiusSlider.leadingAnchor.constraint(equalTo: sliderContainerView.leadingAnchor, constant: 16),
            radiusSlider.trailingAnchor.constraint(equalTo: sliderContainerView.trailingAnchor, constant: -16),
            
            // Done Button
            doneButton.topAnchor.constraint(equalTo: radiusSlider.bottomAnchor, constant: 16),
            doneButton.leadingAnchor.constraint(equalTo: sliderContainerView.leadingAnchor, constant: 16),
            doneButton.trailingAnchor.constraint(equalTo: sliderContainerView.trailingAnchor, constant: -16),
            doneButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupMap() {
        mapView.showsUserLocation = true
        
        // Add tap gesture to drop pin
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Set initial region
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        mapView.setRegion(defaultRegion, animated: false)
        
        updateRadiusDisplay()
    }
    
    private func setupSearch() {
        searchBar.delegate = self
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    private func setupSlider() {
        updateRadiusDisplay()
    }
    
    // MARK: - Actions
    @objc private func sliderValueChanged() {
        currentRadiusKm = Double(radiusSlider.value)
    }
    
    @objc private func mapTapped(_ gesture: UITapGestureRecognizer) {
        // Hide results if showing
        if !resultsTableView.isHidden {
            resultsTableView.isHidden = true
            searchBar.resignFirstResponder()
            return
        }
        
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        selectLocation(coordinate: coordinate)
    }
    
    @objc private func doneTapped() {
        guard let coordinate = selectedCoordinate else { return }
        
        // Get location name using LocationService
        Task {
            let displayName = await LocationService.shared.reverseGeocode(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            ) ?? "Selected Location"
            
            await MainActor.run {
                self.delegate?.didSelectLocationRule(
                    location: coordinate,
                    radiusKm: self.currentRadiusKm,
                    displayName: displayName
                )
                
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func selectLocation(coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        
        // Remove existing annotations and overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add new annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Selected Location"
        mapView.addAnnotation(annotation)
        radiusAnnotation = annotation
        
        // Update radius circle
        updateRadiusCircle()
        
        // Center map on selection
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: currentRadiusKm * 1000 * 2,
            longitudinalMeters: currentRadiusKm * 1000 * 2
        )
        mapView.setRegion(region, animated: true)
        
        // Enable done button
        doneButton.isEnabled = true
        doneButton.alpha = 1.0
        
        // Hide search results
        resultsTableView.isHidden = true
        searchBar.resignFirstResponder()
    }
    
    private func updateRadiusDisplay() {
        radiusLabel.text = String(format: "Radius: %.0f km", currentRadiusKm)
    }
    
    private func updateRadiusCircle() {
        guard let coordinate = selectedCoordinate else { return }
        
        // Remove existing circle
        if let circle = radiusCircle {
            mapView.removeOverlay(circle)
        }
        
        // Add new circle
        let circle = MKCircle(center: coordinate, radius: currentRadiusKm * 1000)
        mapView.addOverlay(circle)
        radiusCircle = circle
    }
}

// MARK: - MKMapViewDelegate
extension WatchlistLocationRuleMapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circleOverlay)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - UISearchBarDelegate
extension WatchlistLocationRuleMapViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            resultsTableView.isHidden = true
        } else {
            completer.queryFragment = searchText
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        resultsTableView.isHidden = true
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension WatchlistLocationRuleMapViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        resultsTableView.reloadData()
        resultsTableView.isHidden = searchResults.isEmpty
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// MARK: - UITableViewDelegate & DataSource
extension WatchlistLocationRuleMapViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath)
        let result = searchResults[indexPath.row]
        cell.textLabel?.text = result.title
        cell.detailTextLabel?.text = result.subtitle
        cell.backgroundColor = .systemBackground
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let completion = searchResults[indexPath.row]
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { [weak self] response, error in
            guard let self = self,
                  let mapItem = response?.mapItems.first else { return }
            
            let coordinate = mapItem.placemark.coordinate
            self.searchBar.text = mapItem.name
            self.selectLocation(coordinate: coordinate)
        }
    }
}
