	//
	//  EditWatchlistDetailViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 10/12/25.
	//

import UIKit
import CoreLocation
import MapKit
import SwiftData

	// MARK: - Helper Models
struct Participant {
	let name: String
	let imageName: String
}

@MainActor
class EditWatchlistDetailViewController: UIViewController {

	private let manager = WatchlistManager.shared
	
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
	
		// Location & Search
	private let locationManager = CLLocationManager()

	
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
		self.title = (watchlistToEdit == nil) ? "New Watchlist" : "Edit Watchlist"
		
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
        // Placeholder logic as Participant mapping to new Schema (WatchlistShare) is not fully implemented in UI
        if watchlistType == .shared {
            self.participants = [Participant(name: "You", imageName: "person.circle.fill")]
            // Ideally fetch from watchlist.shares
        } else {
            self.participants = [Participant(name: "You", imageName: "person.circle.fill")]
        }
		participantsTableView.reloadData()
	}
	
	private func populateDataForEdit() {
		if let watchlist = watchlistToEdit {
			titleTextField.text = watchlist.title
			locationSearchBar.text = watchlist.location
            if let start = watchlist.startDate { startDatePicker.date = start }
            if let end = watchlist.endDate { endDatePicker.date = end }
		}
	}
	
		// MARK: - Gesture Setup
	private func setupLocationOptionsInteractions() {
		guard let container = locationOptionsContainer,
			  let mainStack = container.subviews.first as? UIStackView else { return }
		
			// Safety check to ensure the stackview has the expected children
		guard mainStack.arrangedSubviews.count >= 3 else {
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
        }
		
		present(activityVC, animated: true)
	}
	
		// MARK: - Logic Implementation
	private func updateLocationSelection(_ name: String) {
		locationSearchBar.text = name
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
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
		
			// 1. Update Existing Watchlist
		if let watchlist = watchlistToEdit {
            // Direct update on SwiftData object
			watchlist.title = title
            watchlist.location = location
            watchlist.startDate = startDate
            watchlist.endDate = endDate
            // Manager doesn't need explicit update call if object is managed context
            // But we can force save if needed via manager private context save, 
            // or assume autosave / context save happens on run loop.
            // Ideally manager should have a save method exposed or update method.
            // For now, this modifies the object in context.
            
			navigationController?.popViewController(animated: true)
			return
		}
		
			// 2. Create New Watchlist
        manager.addWatchlist(title: title, location: location, startDate: startDate, endDate: endDate, type: watchlistType)
		
		navigationController?.popViewController(animated: true)
	}
	
		// MARK: - Helpers
	private func formatDateRange(start: Date, end: Date) -> String {
		let startStr = DateFormatters.shortDate.string(from: start)
		let endStr = DateFormatters.shortDate.string(from: end)
		return "\(startStr) - \(endStr)"
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
		
		Task { [weak self] in
			guard let self else { return }

			do {
				guard let request = MKReverseGeocodingRequest(location: location) else {
					await MainActor.run {
						self.updateLocationSelection("Location")
					}
					return
				}
				let response = try await request.mapItems
				let item = response.first

				let name = item?.name ?? "Location"

				await MainActor.run {
					self.updateLocationSelection(name)
				}

			} catch {
				await MainActor.run {
					self.updateLocationSelection("Location")
				}
			}
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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
	}
}

// MARK: - MapSelectionDelegate
extension EditWatchlistDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(name: String, lat: Double, lon: Double) {
        updateLocationSelection(name)
    }
}
// MARK: - UI Utilities

