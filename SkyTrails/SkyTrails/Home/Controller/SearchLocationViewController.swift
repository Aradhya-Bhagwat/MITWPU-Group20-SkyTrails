//
//  SearchLocationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit
import MapKit

protocol SearchLocationDelegate: AnyObject {
    func didSelectLocation(name: String, lat: Double, lon: Double, forIndex index: Int)
}

class SearchLocationViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    weak var delegate: SearchLocationDelegate?
    var cellIndex: Int = 0
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchResults = [MKLocalSearchCompletion]()
    private let locationManager = CLLocationManager()
    private var searchQuery: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSearch()
        setupLocationServices()
    }
    
    private func setupUI() {
            self.view.backgroundColor = .systemBackground
        
            tableView.delegate = self
            tableView.dataSource = self
            tableView.tableFooterView = UIView()
        }
        
    private func setupSearch() {
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .pointOfInterest
    }
    
    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    private func isCoordinatePair(_ query: String) -> (lat: Double, lon: Double)? {
        let components = query.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        if (lat >= -90.0 && lat <= 90.0) && (lon >= -180.0 && lon <= 180.0) {
            return (lat, lon)
        }
        return nil
    }

    private func searchByCoordinate(_ coordinate: (lat: Double, lon: Double)) {
        let location = CLLocation(latitude: coordinate.lat, longitude: coordinate.lon)
        searchResults.removeAll()
        
        Task {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                let mapItems = try await request.mapItems
                let placeName = mapItems.first?.name ?? "Geographic Location"
                
                await MainActor.run {
                    self.finalizeSelection(name: placeName, lat: coordinate.lat, lon: coordinate.lon)
                }
            } catch {
                print("Reverse geocoding failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func finalizeSelection(name: String, lat: Double, lon: Double) {
        delegate?.didSelectLocation(name: name, lat: lat, lon: lon, forIndex: cellIndex)
        dismiss(animated: true)
    }

    @IBAction func didTapCancel(_ sender: Any) {
        self.dismiss(animated: true)
    }

    private func reloadSuggestionsOnly() {
        let sectionIndex = 1
        let currentTotalRows = tableView.numberOfRows(inSection: sectionIndex)
        
        tableView.performBatchUpdates({
           
            if currentTotalRows > 0 {
                let paths = (0..<currentTotalRows).map { IndexPath(row: $0, section: sectionIndex) }
                tableView.deleteRows(at: paths, with: .none)
            }
          
            if !searchResults.isEmpty {
                let paths = (0..<searchResults.count).map { IndexPath(row: $0, section: sectionIndex) }
                tableView.insertRows(at: paths, with: .none)
            }
        }, completion: nil)
    }
    
    private func fetchCurrentLocation() {
        let authStatus = locationManager.authorizationStatus
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
             print("Location Access Denied")
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }
}

    extension SearchLocationViewController: UITableViewDataSource, UITableViewDelegate {
        
        func numberOfSections(in tableView: UITableView) -> Int {
            return 3
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            if section == 0 { return 1 }
            if section == 1 { return searchResults.count }
            if section == 2 { return 1 }
            return 0
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
            if indexPath.section == 0 {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchCell", for: indexPath) as? SearchCell else {
                    return UITableViewCell()
                }
                cell.searchBar.delegate = self
                cell.searchBar.text = searchQuery
                
                if searchQuery.isEmpty && !cell.searchBar.isFirstResponder {
                    cell.searchBar.becomeFirstResponder()
                }
                return cell
            }
            else if indexPath.section == 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath)
                let result = searchResults[indexPath.row]
                var content = cell.defaultContentConfiguration()
                content.text = result.title
                content.secondaryText = result.subtitle
                cell.contentConfiguration = content
                return cell
            }
            else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath)
                var content = cell.defaultContentConfiguration()
                content.text = "Current Location"
                content.image = UIImage(systemName: "location.fill")
                cell.contentConfiguration = content
                return cell
            }
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            if indexPath.section == 1 {
                let result = searchResults[indexPath.row]
                let request = MKLocalSearch.Request(completion: result)
                let search = MKLocalSearch(request: request)
                search.start { [weak self] (response, error) in
                    guard let self = self, let coordinate = response?.mapItems.first?.location.coordinate else { return }
                    self.finalizeSelection(name: result.title, lat: coordinate.latitude, lon: coordinate.longitude)
                }
            }
            if indexPath.section == 2 {
                fetchCurrentLocation()
            }
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            if indexPath.section == 0 { return 60 } // Search bar height
            return UITableView.automaticDimension
        }
    }

extension SearchLocationViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchQuery = searchText
        
        if let coordinate = isCoordinatePair(searchText) {
            searchByCoordinate(coordinate)
            return
        }
        
        if searchText.isEmpty {
            searchResults.removeAll()
            reloadSuggestionsOnly()
        } else {
            searchCompleter.queryFragment = searchText
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension SearchLocationViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        reloadSuggestionsOnly()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    }
}

extension SearchLocationViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let request = MKLocalSearch.Request()
        request.region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            
            let name = response?.mapItems.first?.name ?? "Current Location"
            self.finalizeSelection(name: name, lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Error: \(error.localizedDescription)")
    }
}
