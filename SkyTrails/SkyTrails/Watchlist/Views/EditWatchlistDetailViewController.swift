//
//  EditWatchlistDetailViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit
import CoreLocation
import MapKit

// MARK: - Helper Models
struct Participant {
    let name: String
    let imageName: String
}

class EditWatchlistDetailViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var locationSearchBar: UISearchBar!
    @IBOutlet weak var locationOptionsContainer: UIView!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    @IBOutlet weak var inviteContactsView: UIView!
    @IBOutlet weak var suggestionsTableView: UITableView!
    @IBOutlet weak var participantsTableView: UITableView!
    
    // MARK: - Properties
    var watchlistType: WatchlistType = .custom
    
    // Edit Mode Data
    var watchlistToEdit: Watchlist?
    var sharedWatchlistToEdit: SharedWatchlist?
    
    // Location & Search
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []
    
    // Internal State
    private var participants: [Participant] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocationServices()
        configureInitialData()
    }
    
    // MARK: - Setup & Configuration
    private func setupUI() {
        // Navigation
        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
        navigationItem.rightBarButtonItem = saveButton
        self.title = (watchlistToEdit == nil && sharedWatchlistToEdit == nil) ? "New Watchlist" : "Edit Watchlist"
        
        // Background & Styling
        view.backgroundColor = .systemGray6
        
        if let inviteView = inviteContactsView {
            inviteView.layer.cornerRadius = 12
            inviteView.backgroundColor = .white
            inviteView.applyShadow(radius: 8, opacity: 0.05, offset: CGSize(width: 0, height: 2))
        }
        
        // Visibility Logic
        inviteContactsView.isHidden = (watchlistType != .shared)
        suggestionsTableView.isHidden = true
        
        // Delegates
        participantsTableView.delegate = self
        participantsTableView.dataSource = self
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        locationSearchBar.delegate = self
        
        setupLocationOptionsInteractions()
    }
    
    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        searchCompleter.delegate = self
    }
    
    private func configureInitialData() {
        initializeParticipants()
        populateDataForEdit()
    }
    
    private func initializeParticipants() {
        if let shared = sharedWatchlistToEdit {
            self.participants = shared.userImages.enumerated().map { (index, img) in
                index == 0 ? Participant(name: "You", imageName: img) : Participant(name: "Bird Enthusiast \(index)", imageName: img)
            }
        } else {
            self.participants = [Participant(name: "You", imageName: "person.circle.fill")]
        }
        participantsTableView.reloadData()
    }
    
    private func populateDataForEdit() {
        if let watchlist = watchlistToEdit {
            titleTextField.text = watchlist.title
            locationSearchBar.text = watchlist.location
            startDatePicker.date = watchlist.startDate
            endDatePicker.date = watchlist.endDate
        } else if let shared = sharedWatchlistToEdit {
            titleTextField.text = shared.title
            locationSearchBar.text = shared.location
            // Parsing date strings back to Date objects would happen here if needed
        }
    }
    
    // MARK: - Gesture Setup
    private func setupLocationOptionsInteractions() {
        guard let container = locationOptionsContainer,
              let mainStack = container.subviews.first as? UIStackView else { return }
        
        // Safety check to ensure the stackview has the expected children
        guard mainStack.arrangedSubviews.count >= 3 else {
            print("Warning: locationOptionsContainer stack view structure mismatch.")
            return
        }
        
        let currentLocationView = mainStack.arrangedSubviews[0]
        let mapView = mainStack.arrangedSubviews[2]
        
        let locationTap = UITapGestureRecognizer(target: self, action: #selector(didTapCurrentLocation))
        currentLocationView.isUserInteractionEnabled = true
        currentLocationView.addGestureRecognizer(locationTap)
        
        let mapTap = UITapGestureRecognizer(target: self, action: #selector(didTapMap))
        mapView.isUserInteractionEnabled = true
        mapView.addGestureRecognizer(mapTap)
    }
    
    // MARK: - Actions
    @objc private func didTapCurrentLocation() {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            presentAlert(title: "Location Access Denied", message: "Please enable location services in Settings to use this feature.")
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        @unknown default:
            break
        }
    }
    
    @objc private func didTapMap() {
        let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
        guard let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController else { return }
        mapVC.delegate = self
        navigationController?.pushViewController(mapVC, animated: true)
    }
    
    @IBAction func didTapInvite(_ sender: Any) {
        let titleToShare = titleTextField.text ?? "New Watchlist"
        let shareText = "Hey! Join my Bird Watchlist: \(titleToShare) on SkyTrails!"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = inviteContactsView
            popover.sourceRect = inviteContactsView.bounds
        }
        
        activityVC.completionWithItemsHandler = { [weak self] (_, completed, _, _) in
            if completed { self?.simulateAddingParticipants() }
        }
        
        present(activityVC, animated: true)
    }
    
    // MARK: - Logic Implementation
    private func updateLocationSelection(_ name: String) {
        locationSearchBar.text = name
        suggestionsTableView.isHidden = true
        locationSearchBar.resignFirstResponder()
    }
    
    private func simulateAddingParticipants() {
        guard !participants.contains(where: { $0.name == "Aradhya" }) else { return }
        
        let p1 = Participant(name: "Aradhya", imageName: "person.crop.circle")
        let p2 = Participant(name: "Disha", imageName: "person.crop.circle.fill")
        
        participants.append(contentsOf: [p1, p2])
        participantsTableView.reloadData()
        
        presentAlert(title: "Invites Sent", message: "Aradhya and Disha have been added.")
    }
    
    // MARK: - Save Logic
    @objc private func didTapSave() {
        guard let title = titleTextField.text, !title.isEmpty else {
            presentAlert(title: "Missing Info", message: "Please enter a title.")
            return
        }
        
        let location = locationSearchBar.text ?? "Unknown"
        let startDate = startDatePicker.date
        let endDate = endDatePicker.date
        let finalUserImages = participants.map { $0.imageName }
        let manager = WatchlistManager.shared
        
        // 1. Update Existing Custom Watchlist
        if let watchlist = watchlistToEdit {
            manager.updateWatchlist(id: watchlist.id, title: title, location: location, startDate: startDate, endDate: endDate)
            navigationController?.popViewController(animated: true)
            return
        }
        
        // 2. Update Existing Shared Watchlist
        if let shared = sharedWatchlistToEdit {
            let dateRange = formatDateRange(start: startDate, end: endDate)
            
            // Sync local participant changes if necessary
            if let index = manager.sharedWatchlists.firstIndex(where: { $0.id == shared.id }) {
                manager.sharedWatchlists[index].userImages = finalUserImages
            }
            
            manager.updateSharedWatchlist(id: shared.id, title: title, location: location, dateRange: dateRange)
            navigationController?.popViewController(animated: true)
            return
        }
        
        // 3. Create New Custom Watchlist
        if watchlistType == .custom {
            let newWatchlist = Watchlist(
                title: title, location: location, startDate: startDate, endDate: endDate,
                observedBirds: [], toObserveBirds: []
            )
            manager.addWatchlist(newWatchlist)
            
        // 4. Create New Shared Watchlist
        } else if watchlistType == .shared {
            let newShared = SharedWatchlist(
                title: title, location: location,
                dateRange: formatDateRange(start: startDate, end: endDate),
                mainImageName: "bird_placeholder",
                stats: SharedWatchlistStats(greenValue: 0, blueValue: 0),
                userImages: finalUserImages
            )
            manager.addSharedWatchlist(newShared)
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Helpers
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - CoreLocation Delegate
extension EditWatchlistDetailViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Modern Async Geocoding
        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    let city = placemark.locality ?? ""
                    let area = placemark.subLocality ?? ""
                    let country = placemark.country ?? ""
                    
                    let parts = [area, city, country].filter { !$0.isEmpty }
                    let address = parts.joined(separator: ", ")
                    
                    await MainActor.run {
                        self.updateLocationSelection(address)
                    }
                }
            } catch {
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

// MARK: - TableView Delegate & DataSource
extension EditWatchlistDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView == participantsTableView ? participants.count : searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == participantsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ParticipantCell", for: indexPath)
            let participant = participants[indexPath.row]
            
            var content = cell.defaultContentConfiguration()
            content.text = participant.name
            content.image = UIImage(systemName: participant.imageName) ?? UIImage(systemName: "person.circle")
            content.imageProperties.tintColor = .systemBlue
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
            let item = searchResults[indexPath.row]
            cell.textLabel?.text = "\(item.title) \(item.subtitle)"
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == suggestionsTableView {
            let item = searchResults[indexPath.row]
            
            // Modern Async Search
            Task {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = item.title + " " + item.subtitle
                let search = MKLocalSearch(request: request)
                
                do {
                    let response = try await search.start()
                    if let place = response.mapItems.first {
                        let name = place.name ?? item.title
                        await MainActor.run {
                            self.updateLocationSelection(name)
                        }
                    }
                } catch {
                    print("Search failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Search Delegates
extension EditWatchlistDetailViewController: UISearchBarDelegate, MKLocalSearchCompleterDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults = []
            suggestionsTableView.isHidden = true
        } else {
            searchCompleter.queryFragment = searchText
        }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        suggestionsTableView.isHidden = searchResults.isEmpty
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        suggestionsTableView.isHidden = true
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
        suggestionsTableView.isHidden = searchResults.isEmpty
        suggestionsTableView.reloadData()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Completer error: \(error.localizedDescription)")
    }
}

// MARK: - MapSelectionDelegate
extension EditWatchlistDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(_ locationName: String) {
        updateLocationSelection(locationName)
    }
}

// MARK: - UI Utilities
extension UIView {
    func applyShadow(radius: CGFloat, opacity: Float, offset: CGSize, color: UIColor = .black) {
        self.layer.shadowColor = color.cgColor
        self.layer.shadowOpacity = opacity
        self.layer.shadowOffset = offset
        self.layer.shadowRadius = radius
    }
}