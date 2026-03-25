import UIKit
import CoreLocation
import MapKit

protocol LocationPickerDelegate: AnyObject {
    func didSelectLocation(name: String, lat: Double, lon: Double)
}

class LocationPickerViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    
    weak var delegate: LocationPickerDelegate?
    
    private var searchQuery: String = ""
    private var searchResults: [LocationService.LocationSuggestion] = []
    private var savedAddresses: [LocationPreferences.SavedAddress] = []
    private let locationService = LocationService.shared
    
    private var pendingSelection: (name: String, lat: Double, lon: Double)? {
        didSet {

            updateSaveButtonState()
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
	
        setupUI()
        setupTableView()
        loadSavedAddresses()

        updateSaveButtonState()
    }
    
    private func setupUI() {
        title = "Pick Location"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveButtonTapped))
        
        searchBar.delegate = self

        
        // Match the style of DateandLocationViewController
        tableView.backgroundColor = .systemGroupedBackground
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    private func loadSavedAddresses() {
        savedAddresses = LocationPreferences.shared.savedAddresses
        tableView.reloadData()
    }
    

    
    private func updateSaveButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = pendingSelection != nil
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        guard let selection = pendingSelection else { return }
        saveLocation(name: selection.name, lat: selection.lat, lon: selection.lon)
        delegate?.didSelectLocation(name: selection.name, lat: selection.lat, lon: selection.lon)
        dismiss(animated: true)
    }
    
    @IBAction func plusButtonTapped(_ sender: Any) {
        guard let selection = pendingSelection else { return }
        saveLocation(name: selection.name, lat: selection.lat, lon: selection.lon)
        
        // Clear search and selection after saving? Or just keep it? 
        // User might want to save then use it. Let's keep it.
    }
    
    private func fetchCurrentLocation() {
        Task {
            do {
                let locationData = try await locationService.getCurrentLocation()
                await MainActor.run {
                    self.pendingSelection = (name: locationData.displayName, lat: locationData.lat, lon: locationData.lon)
                    self.searchBar.text = locationData.displayName
                }
            } catch {
                let alert = UIAlertController(title: "Location Error", message: "Could not fetch current location.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
    
    private func saveLocation(name: String, lat: Double, lon: Double) {
        LocationPreferences.shared.saveAddress(name: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        loadSavedAddresses()
    }
}

extension LocationPickerViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return searchResults.count
        case 1: return 2 // Map, Current Location
        case 2: return savedAddresses.count
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "suggestionCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "suggestionCell")
            let suggestion = searchResults[indexPath.row]
            cell.textLabel?.text = suggestion.title
            cell.detailTextLabel?.text = suggestion.subtitle
            
            // Checkmark if selected
            let isSelected = pendingSelection?.name == suggestion.title
            cell.accessoryType = isSelected ? .checkmark : .none
            cell.accessoryView = nil
            
            return cell
        } else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            if indexPath.row == 0 {
                cell.textLabel?.text = "Map"
                cell.imageView?.image = UIImage(systemName: "map")
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = nil
            } else {
                cell.textLabel?.text = "Current Location"
                cell.imageView?.image = UIImage(systemName: "location.fill")
                
                cell.accessoryType = .none
                cell.accessoryView = nil
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "savedCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "savedCell")
            let address = savedAddresses[indexPath.row]
            cell.textLabel?.text = address.name
            cell.detailTextLabel?.text = nil
            cell.imageView?.image = UIImage(systemName: "mappin", withConfiguration: UIImage.SymbolConfiguration(scale: .large))
            cell.imageView?.tintColor = .label
            cell.accessoryType = .none

            cell.accessoryView = nil
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            let suggestion = searchResults[indexPath.row]
            Task {
                do {
                    let locationData = try await locationService.geocode(query: suggestion.fullText)
                    await MainActor.run {
                        self.pendingSelection = (name: locationData.displayName, lat: locationData.lat, lon: locationData.lon)
                        self.searchBar.text = locationData.displayName
                        self.searchResults = []
                        self.tableView.reloadData()
                    }
                } catch {
                    await MainActor.run {
                        self.pendingSelection = (name: suggestion.title, lat: 0, lon: 0)
                        self.searchBar.text = suggestion.title
                    }
                }
            }
        } else if indexPath.section == 1 {
            if indexPath.row == 0 {
                let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
                if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
                    mapVC.delegate = self
                    navigationController?.pushViewController(mapVC, animated: true)
                }
            } else {
                fetchCurrentLocation()
            }
        } else if indexPath.section == 2 {
            let address = savedAddresses[indexPath.row]
            delegate?.didSelectLocation(name: address.name, lat: address.latitude, lon: address.longitude)
            dismiss(animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && !searchResults.isEmpty {
            return "Search Results"
        } else if section == 2 && !savedAddresses.isEmpty {
            return "Saved Addresses"
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section == 2 {
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
                if let address = self?.savedAddresses[indexPath.row] {
                    LocationPreferences.shared.removeSavedAddress(id: address.id)
                    self?.loadSavedAddresses()
                }
                completion(true)
            }
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
        return nil
    }
}

extension LocationPickerViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        Task {
            if searchText.isEmpty {
                self.searchResults = []
            } else {
                self.searchResults = await locationService.getAutocompleteSuggestions(for: searchText)
            }
            await MainActor.run {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            }
        }
    }
}

extension LocationPickerViewController: MapSelectionDelegate {
    func didSelectMapLocation(name: String, lat: Double, lon: Double) {
        self.pendingSelection = (name: name, lat: lat, lon: lon)
        self.searchBar.text = name
        navigationController?.popToViewController(self, animated: true)
    }
}
