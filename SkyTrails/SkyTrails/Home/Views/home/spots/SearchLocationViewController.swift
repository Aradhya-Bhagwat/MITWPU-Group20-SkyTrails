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
    
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    weak var delegate: SearchLocationDelegate?
    var cellIndex: Int = 0
    
    // search engine variables
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchResults = [MKLocalSearchCompletion]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSearch()
    }
    
    private func isCoordinatePair(_ query: String) -> (lat: Double, lon: Double)? {
        
        let components = query.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        
        // Simple validation for typical global ranges
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
                     self.delegate?.didSelectLocation(
                        name: placeName,
                        lat: coordinate.lat,
                        lon: coordinate.lon,
                        forIndex: self.cellIndex
                    )
                    self.dismiss(animated: true)
                }
            } catch {
                print("Reverse geocoding failed: \(error.localizedDescription)")
            }
        }
    }

    private func setupUI() {
            self.view.backgroundColor = .systemBackground
            
            // Setup TableView
            tableView.delegate = self
            tableView.dataSource = self
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ResultCell")
            
            // Setup Text Field
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: searchTextField.frame.height))
                searchTextField.leftView = paddingView
                searchTextField.leftViewMode = .always
            searchTextField.borderStyle = .none //Turn off default style first
            searchTextField.layer.cornerRadius = 8
            searchTextField.backgroundColor = .systemGray6
            searchTextField.layer.borderWidth = 1
            searchTextField.layer.borderColor = UIColor.systemGray5.cgColor
            searchTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            searchTextField.placeholder = "  Search for place"
            searchTextField.becomeFirstResponder() // Keyboard up automatically
        }
        
        private func setupSearch() {
            searchCompleter.delegate = self
            // Optional: Bias search to current map region if available
            // searchCompleter.region = ...
            searchCompleter.resultTypes = .pointOfInterest // or .address
        }

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let query = textField.text, !query.isEmpty else {
            searchResults.removeAll()
            tableView.reloadData()
            return
        }
        
        //  Check if the query is a coordinate pair
        if let coordinate = isCoordinatePair(query) {
            // If it is coordinates, bypass the MapKit completer and perform immediate lookup
            searchByCoordinate(coordinate)
            return
        }
        
        // Original MapKit Search flow continues here:
        searchCompleter.queryFragment = query
    }
        @IBAction func didTapCancel(_ sender: Any) {
            self.dismiss(animated: true)
        }
    }

    // MARK: - 1. Handle Auto-Complete Results
    extension SearchLocationViewController: MKLocalSearchCompleterDelegate {
        
        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            // Apple sent back a list of matching places
            searchResults = completer.results
            tableView.reloadData()
        }
        
        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    
        }
    }

    // MARK: - 2. TableView DataSource & Delegate
    extension SearchLocationViewController: UITableViewDataSource, UITableViewDelegate {
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return searchResults.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath)
            
            let result = searchResults[indexPath.row]
            
            // Standard Apple style: Title + Subtitle
            var content = cell.defaultContentConfiguration()
            content.text = result.title
            content.secondaryText = result.subtitle
            cell.contentConfiguration = content
            
            return cell
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            
            let selectedResult = searchResults[indexPath.row]
            
            // The completer only gives text. We need 'MKLocalSearch' to get Lat/Lon.
            let searchRequest = MKLocalSearch.Request(completion: selectedResult)
            let search = MKLocalSearch(request: searchRequest)
            
            search.start { [weak self] (response, error) in
                guard let self = self else { return }
                
                if let coordinate = response?.mapItems.first?.location.coordinate {

                    
                    // Send real data back to the Card
                    self.delegate?.didSelectLocation(
                        name: selectedResult.title,
                        lat: coordinate.latitude,
                        lon: coordinate.longitude,
                        forIndex: self.cellIndex
                    )
                    
                    self.dismiss(animated: true)
                } else {

                }
            }
        }
    
}
