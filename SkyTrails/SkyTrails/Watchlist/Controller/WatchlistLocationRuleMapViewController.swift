
import UIKit
import MapKit
import CoreLocation

protocol WatchlistLocationRuleDelegate: AnyObject {
    func didSelectLocationRule(location: CLLocationCoordinate2D, radiusKm: Double, displayName: String)
}

@MainActor
class WatchlistLocationRuleMapViewController: UIViewController {
    private let mapView = MKMapView()
    private let searchContainerView = UIView()
    private let searchBar = UISearchBar()
    private let resultsTableView = UITableView()
    private let sliderContainerView = UIView()
    private let radiusSlider = UISlider()
    private let radiusLabel = UILabel()
    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    
    weak var delegate: WatchlistLocationRuleDelegate?
    private let completer = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []
    private var selectedCoordinate: CLLocationCoordinate2D?
    private var radiusCircle: MKCircle?
    private var currentRadiusKm: Double = 50.0 {
        didSet {
            updateRadiusDisplay()
            updateRadiusCircle()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMap()
        setupSearch()
    }
    
    private func setupUI() {
        title = "Region Boundary"
        view.backgroundColor = .systemBackground
        
        // Search Container
        searchContainerView.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.backgroundColor = .systemBackground
        searchContainerView.layer.cornerRadius = 14
        searchContainerView.layer.shadowColor = UIColor.black.cgColor
        searchContainerView.layer.shadowOpacity = 0.1
        searchContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchContainerView.layer.shadowRadius = 8
        view.addSubview(searchContainerView)
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search for a location"
        searchBar.searchBarStyle = .minimal
        searchContainerView.addSubview(searchBar)
        
        // Map View
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsUserLocation = true
        view.addSubview(mapView)
        
        // Results Table
        resultsTableView.translatesAutoresizingMaskIntoConstraints = false
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ResultCell")
        resultsTableView.isHidden = true
        resultsTableView.layer.cornerRadius = 14
        resultsTableView.layer.masksToBounds = true
        resultsTableView.backgroundColor = .systemBackground
        view.addSubview(resultsTableView)
        
        // Slider Container (Floating Card style)
        sliderContainerView.translatesAutoresizingMaskIntoConstraints = false
        sliderContainerView.backgroundColor = .systemBackground
        sliderContainerView.layer.cornerRadius = 24
        sliderContainerView.layer.shadowColor = UIColor.black.cgColor
        sliderContainerView.layer.shadowOpacity = 0.15
        sliderContainerView.layer.shadowOffset = CGSize(width: 0, height: -4)
        sliderContainerView.layer.shadowRadius = 12
        view.addSubview(sliderContainerView)
        
        radiusLabel.translatesAutoresizingMaskIntoConstraints = false
        radiusLabel.font = .systemFont(ofSize: 18, weight: .bold)
        radiusLabel.textAlignment = .center
        sliderContainerView.addSubview(radiusLabel)
        
        setupRadiusControl()
        
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("Confirm Region", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        doneButton.backgroundColor = .systemBlue
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.layer.cornerRadius = 16
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.isEnabled = false
        doneButton.alpha = 0.5
        sliderContainerView.addSubview(doneButton)
        
        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            searchContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainerView.heightAnchor.constraint(equalToConstant: 50),
            
            searchBar.topAnchor.constraint(equalTo: searchContainerView.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -4),
            searchBar.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor),
            
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: sliderContainerView.topAnchor, constant: 20),
            
            resultsTableView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 8),
            resultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultsTableView.heightAnchor.constraint(equalToConstant: 240),
            
            sliderContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sliderContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sliderContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sliderContainerView.heightAnchor.constraint(equalToConstant: 220),
            
            radiusLabel.topAnchor.constraint(equalTo: sliderContainerView.topAnchor, constant: 24),
            radiusLabel.centerXAnchor.constraint(equalTo: sliderContainerView.centerXAnchor),
            
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            doneButton.leadingAnchor.constraint(equalTo: sliderContainerView.leadingAnchor, constant: 24),
            doneButton.trailingAnchor.constraint(equalTo: sliderContainerView.trailingAnchor, constant: -24),
            doneButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupRadiusControl() {
        let controlStack = UIStackView()
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        controlStack.axis = .horizontal
        controlStack.spacing = 16
        controlStack.alignment = .center
        sliderContainerView.addSubview(controlStack)
        
        minusButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        minusButton.tintColor = .systemGray2
        minusButton.contentVerticalAlignment = .fill
        minusButton.contentHorizontalAlignment = .fill
        minusButton.addTarget(self, action: #selector(minusTapped), for: .touchUpInside)
        
        plusButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        plusButton.tintColor = .systemGray2
        plusButton.contentVerticalAlignment = .fill
        plusButton.contentHorizontalAlignment = .fill
        plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)
        
        radiusSlider.minimumValue = 1
        radiusSlider.maximumValue = 200
        radiusSlider.value = Float(currentRadiusKm)
        radiusSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        controlStack.addArrangedSubview(minusButton)
        controlStack.addArrangedSubview(radiusSlider)
        controlStack.addArrangedSubview(plusButton)
        
        NSLayoutConstraint.activate([
            controlStack.topAnchor.constraint(equalTo: radiusLabel.bottomAnchor, constant: 20),
            controlStack.leadingAnchor.constraint(equalTo: sliderContainerView.leadingAnchor, constant: 24),
            controlStack.trailingAnchor.constraint(equalTo: sliderContainerView.trailingAnchor, constant: -24),
            
            minusButton.widthAnchor.constraint(equalToConstant: 32),
            minusButton.heightAnchor.constraint(equalToConstant: 32),
            plusButton.widthAnchor.constraint(equalToConstant: 32),
            plusButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupMap() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Initial region - zoom to user or a default
        if let userLocation = mapView.userLocation.location?.coordinate {
            let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: 50000, longitudinalMeters: 50000)
            mapView.setRegion(region, animated: false)
        }
        
        updateRadiusDisplay()
    }
    
    private func setupSearch() {
        searchBar.delegate = self
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    @objc private func sliderValueChanged() {
        currentRadiusKm = Double(radiusSlider.value)
    }
    
    @objc private func minusTapped() {
        currentRadiusKm = max(1, currentRadiusKm - 5)
        radiusSlider.setValue(Float(currentRadiusKm), animated: true)
    }
    
    @objc private func plusTapped() {
        currentRadiusKm = min(200, currentRadiusKm + 5)
        radiusSlider.setValue(Float(currentRadiusKm), animated: true)
    }
    
    @objc private func mapTapped(_ gesture: UITapGestureRecognizer) {
        if !resultsTableView.isHidden {
            hideSearchResults()
            return
        }
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        selectLocation(coordinate: coordinate)
    }
    
    private func selectLocation(coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        mapView.removeAnnotations(mapView.annotations)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        
        updateRadiusCircle()
        
        // Smoother animated transition
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: currentRadiusKm * 1000 * 2.5,
            longitudinalMeters: currentRadiusKm * 1000 * 2.5
        )
        mapView.setRegion(region, animated: true)
        
        doneButton.isEnabled = true
        doneButton.alpha = 1.0
    }
    
    private func updateRadiusCircle() {
        guard let coordinate = selectedCoordinate else { return }
        if let circle = radiusCircle {
            mapView.removeOverlay(circle)
        }
        let circle = MKCircle(center: coordinate, radius: currentRadiusKm * 1000)
        mapView.addOverlay(circle)
        radiusCircle = circle
    }
    
    private func updateRadiusDisplay() {
        radiusLabel.text = String(format: "Radius: %.0f km", currentRadiusKm)
    }
    
    private func hideSearchResults() {
        resultsTableView.isHidden = true
        searchBar.resignFirstResponder()
    }
    
    @objc private func doneTapped() {
        guard let coordinate = selectedCoordinate else { return }
        Task {
            let displayName = await LocationService.shared.reverseGeocode(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            ) ?? "Selected Area"
            
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
}

extension WatchlistLocationRuleMapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circleOverlay)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.6)
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

extension WatchlistLocationRuleMapViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            resultsTableView.isHidden = true
        } else {
            completer.queryFragment = searchText
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        hideSearchResults()
    }
}

extension WatchlistLocationRuleMapViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        resultsTableView.reloadData()
        resultsTableView.isHidden = searchResults.isEmpty
    }
}

extension WatchlistLocationRuleMapViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath)
        let result = searchResults[indexPath.row]
        cell.textLabel?.text = result.title
        cell.detailTextLabel?.text = result.subtitle
        cell.textLabel?.font = .systemFont(ofSize: 16)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let completion = searchResults[indexPath.row]
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { [weak self] response, error in
            guard let self = self, let mapItem = response?.mapItems.first else { return }
            self.searchBar.text = mapItem.name
            self.hideSearchResults()
            self.selectLocation(coordinate: mapItem.location.coordinate)
        }
    }
}
