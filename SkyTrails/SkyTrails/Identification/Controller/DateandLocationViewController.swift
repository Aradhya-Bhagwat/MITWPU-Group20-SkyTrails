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
    private var searchResults: [LocationService.LocationSuggestion] = []
    
    private let locationService = LocationService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        
        if let mappedLocation = viewModel.locationName(for: viewModel.selectedLocationId) {
            searchQuery = mappedLocation
            viewModel.selectedLocation = mappedLocation
        } else if let currentLoc = viewModel.selectedLocation {
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
   
    @IBAction func nextTapped(_ sender: Any) {
        // 1. Sync state to manager
        viewModel.selectedDate = selectedDate
        viewModel.selectedLocation = searchQuery.isEmpty ? nil : searchQuery
        if searchQuery.isEmpty {
            viewModel.selectedLocationId = nil
        } else {
            viewModel.registerLocationName(searchQuery, for: viewModel.selectedLocationId)
        }
        
        // 2. Trigger the prediction filter
        viewModel.runFilter()
        
        // 3. Navigate to next step
        delegate?.didFinishStep()
    }
    
    private func updateLocationSelection(_ name: String) {
        print("DateandLocationViewController: updateLocationSelection() called with name: '\(name)'.")
        
        viewModel.selectedLocation = name
        viewModel.registerLocationName(name, for: viewModel.selectedLocationId)
        searchQuery = name
        searchResults = []
        dateandlocationTableView.reloadData()
        view.endEditing(true)
    }
    private func fetchCurrentLocationName() {
        Task {
            do {
                let locationData = try await locationService.getCurrentLocation()
                await MainActor.run {
                    self.viewModel.selectedLocationId = UUID()
                    self.updateLocationSelection(locationData.displayName)
                }
            } catch {
                if let locError = error as? LocationService.LocationError,
                      locError == .locationAccessDenied {
                    print("Failed to get current location: \(error)")
                    let alert = UIAlertController(title: "Location Error", message: "Could not fetch current location. Please check your settings.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    await MainActor.run { self.present(alert, animated: true) }
                       return
                   }

                
            }
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
            cell.datePicker.date = selectedDate // Set the date picker's date
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
            let suggestion = searchResults[indexPath.row - 1]
            Task {
                do {
                    let locationData = try await locationService.geocode(query: suggestion.fullText)
                    await MainActor.run {
                        self.viewModel.selectedLocationId = suggestion.id
                        self.updateLocationSelection(locationData.displayName)
                    }
                } catch {
                    // Fallback to the suggestion title if geocoding fails for any reason
                    await MainActor.run {
                        self.viewModel.selectedLocationId = suggestion.id
                        self.updateLocationSelection(suggestion.title)
                    }
                                    
                    print("Could not geocode suggestion '\(suggestion.fullText)': \(error)")
                }
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
            viewModel.selectedLocationId = nil
        }
        Task {
            if searchText.isEmpty {
                self.searchResults = []
            } else {
                self.searchResults = await locationService.getAutocompleteSuggestions(for: searchText)
            }
            await MainActor.run {
                self.dateandlocationTableView.reloadSections(IndexSet(integer: 1), with: .none)
            }
        }
    }
}

extension DateandLocationViewController: DateInputCellDelegate, MapSelectionDelegate {
    func dateInputCell(_ cell: DateInputCell, didPick date: Date) {
        selectedDate = date
    }
    
    func didSelectMapLocation(name: String, lat: Double, lon: Double) {
        viewModel.selectedLocationId = UUID()
        updateLocationSelection(name)
    }
}

extension DateandLocationViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let progress = Float(current) / Float(total)
        progressView.setProgress(progress, animated: true)
    }
}
