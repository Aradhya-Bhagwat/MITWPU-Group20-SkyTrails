import UIKit
import CoreLocation
import MapKit

class DateandLocationViewController: UIViewController {


    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var dateandlocationTableView: UITableView!
    @IBOutlet weak var progressView: UIProgressView!
    

    var viewModel: IdentificationModels!
    weak var delegate: IdentificationFlowStepDelegate?
    
    
    private var selectedDate: Date? = Date()
    private var searchQuery: String = "" // The active text in the bar
    private var searchResults: [MKLocalSearchCompletion] = []
    
    
    private let locationManager = CLLocationManager()
    private var completer = MKLocalSearchCompleter()
    
   
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupCompleter()
        setupLocationServices()
        setupRightTickButton()
        // Pre-fill query if we already have a location selected
        if let currentLoc = viewModel.selectedLocation {
            searchQuery = currentLoc
        }
    }
    
    private func setupUI() {
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
        
        tableContainerView.backgroundColor = .white
        tableContainerView.layer.cornerRadius = 12
        tableContainerView.layer.shadowColor = UIColor.black.cgColor
        tableContainerView.layer.shadowOpacity = 0.1
        tableContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        tableContainerView.layer.shadowRadius = 8
        tableContainerView.layer.masksToBounds = false
    }
    
    private func setupTableView() {
        let nib = UINib(nibName: "DateInputCell", bundle: nil)
        dateandlocationTableView.register(nib, forCellReuseIdentifier: "DateInputCell")
        
        dateandlocationTableView.delegate = self
        dateandlocationTableView.dataSource = self
        
        // Hide empty rows
        dateandlocationTableView.tableFooterView = UIView()
    }
    
    private func setupCompleter() {
        completer.delegate = self
    }
    private func setupRightTickButton() {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "checkmark", withConfiguration: config), for: .normal)
        button.tintColor = .black
        
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

    @objc private func nextTapped() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        let formattedDate = formatter.string(from: selectedDate ?? Date())
        
        viewModel.data.date = formattedDate
     
        
        viewModel.filterBirds(
            shape: viewModel.selectedShapeId,
            size: viewModel.selectedSizeCategory,
            location: viewModel.selectedLocation,
            fieldMarks: []
        )
        
        delegate?.didFinishStep()
    }
    
    private func updateLocationSelection(_ name: String) {
 
        viewModel.selectedLocation = name
        viewModel.data.location = name
        
        // Update UI State
        searchQuery = name
        searchResults = [] // Clear suggestions
        
        // Update Table
        // We reload everything to ensure the search bar shows the committed text
        // and suggestions disappear.
        dateandlocationTableView.reloadData()
        view.endEditing(true) // Dismiss keyboard
    }
    
    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    private func fetchCurrentLocationName() {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            let alert = UIAlertController(title: "Location Access Denied", message: "Please enable location services in Settings to use this feature.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }
}


extension DateandLocationViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        if section == 1 { return 1 + searchResults.count }
        if section == 2 { return 2 }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
       
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as! DateInputCell
            cell.delegate = self
           
            return cell
        }
        
        
        if indexPath.section == 1 {
            
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SearchCell", for: indexPath) as! SearchCell
                cell.searchBar.delegate = self
                cell.searchBar.text = searchQuery
                return cell
            }
            
            
            let suggestionIndex = indexPath.row - 1
            if suggestionIndex < searchResults.count {
                let item = searchResults[suggestionIndex]
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "suggestionCell")
                cell.textLabel?.text = item.title
                cell.detailTextLabel?.text = item.subtitle
                return cell
            }
        }
        
        // Section 2: Static Options
        if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "location_cell", for: indexPath)
            if indexPath.row == 0 {
                cell.textLabel?.text = "Map"
                cell.imageView?.image = UIImage(systemName: "map")
            } else {
                cell.textLabel?.text = "Current Location"
                cell.imageView?.image = UIImage(systemName: "location.fill")
                cell.accessoryType = .disclosureIndicator
            }
            return cell
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Handle Suggestion Tap
        if indexPath.section == 1 && indexPath.row > 0 {
            let suggestionIndex = indexPath.row - 1
            let completion = searchResults[suggestionIndex]
            
            Task {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = completion.title + " " + completion.subtitle
                let search = MKLocalSearch(request: request)
                
                do {
                    let response = try await search.start()
                    if let place = response.mapItems.first {
                        let name = place.name ?? completion.title
                        await MainActor.run {
                            self.updateLocationSelection(name)
                        }
                    }
                } catch {
                    print("Search failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Handle Map Tap
        if indexPath.section == 2 && indexPath.row == 0 {
            let storyboard = UIStoryboard(name:"SharedStoryboard",bundle:nil)
            if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
                mapVC.delegate = self
                navigationController?.pushViewController(mapVC, animated: true)
            }
        }
        
        // Handle Current Location Tap
        if indexPath.section == 2 && indexPath.row == 1 {
            fetchCurrentLocationName()
        }
    }
}


extension DateandLocationViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // 1. Update State
        searchQuery = searchText
        
        // 2. Clear previous selection state if user starts typing again
        if !searchText.isEmpty {
            viewModel.selectedLocation = nil // or keep it, depending on preference
        }
        
        // 3. Trigger Search
        if searchText.isEmpty {
            searchResults = []
            reloadSuggestionsOnly()
        } else {
            completer.queryFragment = searchText
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension DateandLocationViewController: MKLocalSearchCompleterDelegate {
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
        reloadSuggestionsOnly()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Handle error if needed
    }
    
    // Helper to reload strictly the suggestion rows, NOT the search bar row.
    // This prevents the search bar from resigning first responder.
    private func reloadSuggestionsOnly() {
        let sectionIndex = 1
        
        // 1. Calculate how many suggestion rows we currently have
        let currentTotalRows = dateandlocationTableView.numberOfRows(inSection: sectionIndex)
        let currentSuggestionCount = currentTotalRows - 1 // Subtract the SearchBar row
        
        // 2. Perform updates without touching Row 0
        dateandlocationTableView.performBatchUpdates({
            // Remove old suggestions
            if currentSuggestionCount > 0 {
                let indexPathsToDelete = (1...currentSuggestionCount).map {
                    IndexPath(row: $0, section: sectionIndex)
                }
                dateandlocationTableView.deleteRows(at: indexPathsToDelete, with: .none)
            }
            
            // Insert new suggestions
            if !searchResults.isEmpty {
                let indexPathsToInsert = (1...searchResults.count).map {
                    IndexPath(row: $0, section: sectionIndex)
                }
                dateandlocationTableView.insertRows(at: indexPathsToInsert, with: .none)
            }
        }, completion: nil)
    }
}


extension DateandLocationViewController: DateInputCellDelegate, MapSelectionDelegate {
    func dateInputCell(_ cell: DateInputCell, didPick date: Date) {
        selectedDate = date
    }
    
    func didSelectMapLocation(name: String, lat: Double, lon: Double) {
        updateLocationSelection(name)
    }
}


extension DateandLocationViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {

        guard let location = locations.last else { return }

        Task { [weak self] in
            guard let self else { return }

            do {
                // Create MapKit reverse geocoding request
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    await MainActor.run {
                        self.updateLocationSelection("Location")
                    }
                    return
                }

                // Perform reverse geocoding
                let response = try await request.mapItems
                let item = response.first

                let name = item?.name ?? "Location"

                // Update UI + model on main thread
                await MainActor.run {
                    self.updateLocationSelection(name)
                }

            } catch {
                await MainActor.run {
                    self.updateLocationSelection("Location")
                }
                print("Reverse geocoding failed: \(error.localizedDescription)")
            }
        }
    }

    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
