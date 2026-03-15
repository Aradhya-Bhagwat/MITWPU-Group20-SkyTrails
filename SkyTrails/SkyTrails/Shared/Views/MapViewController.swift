
import UIKit
import MapKit
import CoreLocation

protocol MapSelectionDelegate: AnyObject {
    func didSelectMapLocation(name: String, lat: Double, lon: Double)
}

class MapViewController: UIViewController {

    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchPillView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    
    @IBOutlet weak var resultsTableView: UITableView!

    
    private let locationManager = CLLocationManager()
    private var completer = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []
    
    weak var delegate: MapSelectionDelegate?
    var selectedLocationName: String?
    var selectedCoordinate: CLLocationCoordinate2D?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMap()
        setupSearch()
    }

    
    private func setupUI() {
        searchPillView.layer.cornerRadius = 28
        searchPillView.layer.shadowColor = UIColor.black.cgColor
        searchPillView.layer.shadowOpacity = 0.15
        searchPillView.layer.shadowOffset = CGSize(width: 0, height: 4)
        searchPillView.layer.shadowRadius = 6
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Search for a location"
        resultsTableView.layer.cornerRadius = 20
        resultsTableView.layer.masksToBounds = true
        resultsTableView.isHidden = true
        resultsTableView.alpha = 0
        resultsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ResultCell")
    }
    
    private func setupMap() {
        mapView.delegate = self
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        let tap = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tap)
    }
    
    private func setupSearch() {
        searchBar.delegate = self
        completer.delegate = self
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
    }
    @objc func mapTapped(_ sender: UITapGestureRecognizer) {
        if !resultsTableView.isHidden {
            toggleResults(show: false)
            searchBar.resignFirstResponder()
            return
        }
        
        let point = sender.location(in: mapView)
        let coord = mapView.convert(point, toCoordinateFrom: mapView)
        
        updateLocationOnMap(coord: coord)
    }
    
    func updateLocationOnMap(coord: CLLocationCoordinate2D, name: String? = nil) {
        self.selectedCoordinate = coord
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coord
        mapView.addAnnotation(annotation)
        
        // Initial wide region for "zoom from space" effect
        let currentRegion = mapView.region
        let wideSpan = MKCoordinateSpan(
            latitudeDelta: max(currentRegion.span.latitudeDelta, 1.5),
            longitudeDelta: max(currentRegion.span.longitudeDelta, 1.5)
        )
        let wideRegion = MKCoordinateRegion(center: coord, span: wideSpan)
        mapView.setRegion(wideRegion, animated: false)
        
        // Animate to target zoom
        let targetRegion = MKCoordinateRegion(center: coord, latitudinalMeters: 3000, longitudinalMeters: 3000)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mapView.setRegion(targetRegion, animated: true)
        }

        if let providedName = name {
            self.selectedLocationName = providedName
            self.searchBar.text = providedName
        } else {
            reverseGeocode(coord)
        }
    }

   
    func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coord.latitude,
                                  longitude: coord.longitude)
        Task { [weak self] in
            guard let self else { return }

            do {
             
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    await MainActor.run {
                        self.selectedLocationName = "Location"
                        self.searchBar.text = "Location"
                    }
                    return
                }
                let response = try await request.mapItems
                let item = response.first

                let name = item?.name ?? "Location"

                self.selectedLocationName = name
                self.searchBar.text = name

            } catch {
               
                    self.selectedLocationName = "Location"
                    self.searchBar.text = "Location"
                
            }
        }
    }

    
    func toggleResults(show: Bool) {
        if show {
            resultsTableView.isHidden = false
            UIView.animate(withDuration: 0.2) { self.resultsTableView.alpha = 1.0 }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.resultsTableView.alpha = 0
            }) { _ in
                self.resultsTableView.isHidden = true
            }
        }
    }

    @IBAction func nextTapped(_ sender: Any) {
        guard let name = selectedLocationName, let coord = selectedCoordinate else { return }
        delegate?.didSelectMapLocation(name: name, lat: coord.latitude, lon: coord.longitude)
        navigationController?.popViewController(animated: true)
    }
    
}

extension MapViewController: MKMapViewDelegate, CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
}

extension MapViewController: UISearchBarDelegate, MKLocalSearchCompleterDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            toggleResults(show: false)
        } else {
            completer.queryFragment = searchText
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        toggleResults(show: false)
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
        self.resultsTableView.reloadData()
        let shouldShow = !searchResults.isEmpty && !(searchBar.text?.isEmpty ?? true)
        toggleResults(show: shouldShow)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    }
}

extension MapViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ResultCell")
        let result = searchResults[indexPath.row]
        cell.textLabel?.text = result.title
        cell.detailTextLabel?.text = result.subtitle
        cell.backgroundColor = .clear
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let completion = searchResults[indexPath.row]
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        search.start { [weak self] response, _ in
            guard let self = self,
                  let mapItem = response?.mapItems.first
            else { return }

            let coord = mapItem.location.coordinate
            let name = mapItem.name ?? completion.title

            
            self.updateLocationOnMap(coord: coord, name: name)
            self.toggleResults(show: false)
            self.searchBar.resignFirstResponder()
        }
    }

}

