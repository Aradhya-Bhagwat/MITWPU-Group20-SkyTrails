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
    
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var grabberView: UIView!
    
    @IBOutlet weak var floatingSearchView: UIView!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
  
    @IBOutlet weak var sheetBackgroundView: UIView!
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
        containerView.backgroundColor = .clear
        searchLocationTableView.backgroundColor = .clear
        view.backgroundColor = .clear
        searchBar.delegate = self
        searchLocationTableView.delegate = self
        searchLocationTableView.dataSource = self
        searchLocationTableView.rowHeight = UITableView.automaticDimension
        searchLocationTableView.estimatedRowHeight = 44
        completer.delegate = self
        styleGrabber()
         styleFloatingSearch()
         styleSheetBackground()

//       view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        
    }
    private func styleGrabber() {
        grabberView.layer.cornerRadius = 2.5
        grabberView.backgroundColor = UIColor.systemGray4
        grabberView.clipsToBounds = true
    }

    private func styleFloatingSearch() {
        floatingSearchView.layer.cornerRadius = 28
        floatingSearchView.layer.masksToBounds = false
        floatingSearchView.layer.shadowColor = UIColor.black.cgColor
        floatingSearchView.layer.shadowOpacity = 0.12
        floatingSearchView.layer.shadowOffset = CGSize(width: 0, height: 3)
        floatingSearchView.layer.shadowRadius = 8
        floatingSearchView.backgroundColor = .white

        searchBar.backgroundImage = UIImage()
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        searchBar.searchBarStyle = .minimal

        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = .clear
            textField.borderStyle = .none
            textField.layer.cornerRadius = 0
            textField.clipsToBounds = true
        }

        searchBar.searchTextField.leftView?.tintColor = UIColor.darkGray
        searchBar.searchTextField.textColor = UIColor.black
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [.foregroundColor: UIColor.gray]
        )

    }

    private func styleSheetBackground() {
        sheetBackgroundView.backgroundColor = .white
        sheetBackgroundView.layer.cornerRadius = 30
        sheetBackgroundView.clipsToBounds = true
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
            self.view.endEditing(true)
            
            // ✅ Auto-dismiss the bottom sheet
            DispatchQueue.main.async {
                self.dismiss(animated: true)
            }
        }
    }
    
}
extension LocationBottomSheetViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.suggestions = completer.results
        searchLocationTableView.reloadData()
    }
}

