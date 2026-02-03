import UIKit
import CoreLocation
import MapKit

class DateandLocationViewController: UIViewController {

    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var dateandlocationTableView: UITableView!
    @IBOutlet weak var progressView: UIProgressView!

    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    private var selectedDate: Date = Date()
    private var searchQuery: String = ""
    private var searchResults: [MKLocalSearchCompletion] = []
    
    private let locationManager = CLLocationManager()
    private var completer = MKLocalSearchCompleter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupCompleter()
        setupLocationServices()
        

        if let currentLoc = viewModel.selectedLocation {
            searchQuery = currentLoc
        }
        selectedDate = viewModel.selectedDate
    }
    
    private func setupUI() {
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    private func setupTableView() {
        let nib = UINib(nibName: "DateInputCell", bundle: nil)
        dateandlocationTableView.register(nib, forCellReuseIdentifier: "DateInputCell")
        
        dateandlocationTableView.delegate = self
        dateandlocationTableView.dataSource = self
    }
    
    private func setupCompleter() {
        completer.delegate = self
    }
   
    @IBAction func nextTapped(_ sender: Any) {
        // 1. Sync state to manager
        viewModel.selectedDate = selectedDate
        viewModel.selectedLocation = searchQuery.isEmpty ? nil : searchQuery
        
        // 2. Trigger the prediction filter
        viewModel.runFilter()
        
        // 3. Navigate to next step
        delegate?.didFinishStep()
    }
    
    private func updateLocationSelection(_ name: String) {
        print("DateandLocationViewController: updateLocationSelection() called with name: '\(name)'.")
        
        viewModel.selectedLocation = name
        searchQuery = name
        searchResults = []
        dateandlocationTableView.reloadData()
        view.endEditing(true)
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
            let alert = UIAlertController(title: "Location Access Denied", message: "Please enable location services in Settings.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }
}

// MARK: - TableView DataSource & Delegate
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
            let item = searchResults[suggestionIndex]
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "suggestionCell")
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = item.subtitle
            return cell
        }

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
        
        if indexPath.section == 1 && indexPath.row > 0 {
            let completion = searchResults[indexPath.row - 1]
            Task {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = completion.title + " " + completion.subtitle
                let search = MKLocalSearch(request: request)
                do {
                    let response = try await search.start()
                    if let place = response.mapItems.first {
                        let name = place.name ?? completion.title
                        await MainActor.run { self.updateLocationSelection(name) }
                    }
                } catch { print("Search failed: \(error)") }
            }
        }

        if indexPath.section == 2 && indexPath.row == 0 {
            let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
            if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
                mapVC.delegate = self
                navigationController?.pushViewController(mapVC, animated: true)
            }
        }
        
        if indexPath.section == 2 && indexPath.row == 1 {
            fetchCurrentLocationName()
        }
    }
}

// MARK: - Search Logic
extension DateandLocationViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchQuery = searchText
        if searchText.isEmpty {
            searchResults = []
            dateandlocationTableView.reloadData()
        } else {
            completer.queryFragment = searchText
        }
    }
}

extension DateandLocationViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
        dateandlocationTableView.reloadSections(IndexSet(integer: 1), with: .none)
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("DateandLocationViewController: locationManager didUpdateLocations with \(locations.count) location(s).")
        guard let location = locations.last else {
            print("DateandLocationViewController: No location found in the update.")
            return
        }
        print("DateandLocationViewController: Last location is \(location.coordinate). Starting reverse geocoding.")

        Task { [weak self] in
            guard let self else { return }
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    print("DateandLocationViewController: Failed to create MKReverseGeocodingRequest.")
                    await MainActor.run { self.updateLocationSelection("Location") }
                    return
                }

                print("DateandLocationViewController: Awaiting reverse geocoding response...")
                let response = try await request.mapItems
                let item = response.first

                let name = item?.name ?? "Location"
                print("DateandLocationViewController: Reverse geocoding successful. Found name: '\(name)'.")
                await MainActor.run { self.updateLocationSelection(name) }
            } catch {
                await MainActor.run {
                    print("DateandLocationViewController: Reverse geocoding failed.")
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

extension DateandLocationViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let progress = Float(current) / Float(total)
        progressView.setProgress(progress, animated: true)
    }
}
