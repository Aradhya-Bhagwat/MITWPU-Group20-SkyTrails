//
//  LocationBottomSheetViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit
import CoreLocation
import MapKit

protocol LocationSearchDelegate: AnyObject {
    func locationSelected(_ coordinate: CLLocationCoordinate2D, name: String?)
}

class LocationBottomSheetViewController: UIViewController {
    
   
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var searchLocationTableView: UITableView!
    
    var selectedCoordinate: CLLocationCoordinate2D?
    weak var delegate: LocationSearchDelegate?
    private var results: [MKMapItem] = []
    private let completer = MKLocalSearchCompleter()
    private var suggestions: [MKLocalSearchCompletion] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let coord = selectedCoordinate {
            print("Bottom sheet received coordinate:", coord)
          
        }
        searchBar.delegate = self
        searchLocationTableView.delegate = self
        searchLocationTableView.dataSource = self
        searchLocationTableView.rowHeight = UITableView.automaticDimension
        searchLocationTableView.estimatedRowHeight = 44
        completer.delegate = self
        
//        searchBar.searchTextField.backgroundColor = .secondarySystemBackground
//        searchBar.searchTextField.layer.cornerRadius = 12
//        searchBar.searchTextField.clipsToBounds = true
//        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        
    }

    private func searchPlaces(with query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            
            if let items = response?.mapItems {
                self.results = items
                DispatchQueue.main.async {
                    self.searchLocationTableView.reloadData()
                }
            } else if let error = error {
                print("Search error:", error.localizedDescription)
            }
        }
    }

  

}

extension LocationBottomSheetViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
           completer.queryFragment = searchText
       }

       func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
           searchBar.resignFirstResponder()
       }
}

extension LocationBottomSheetViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestions.count

        
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
        let item = suggestions[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.subtitle
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let completion = suggestions[indexPath.row]
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        search.start { [weak self] response, error in
            guard let self = self else { return }
            guard let item = response?.mapItems.first else { return }

            self.delegate?.locationSelected(item.placemark.coordinate, name: item.name)
        }
    }
    
}
extension LocationBottomSheetViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.suggestions = completer.results
        searchLocationTableView.reloadData()
    }
}

