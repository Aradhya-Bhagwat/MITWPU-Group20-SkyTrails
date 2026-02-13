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
	private let locationService = LocationService.shared
	
		// MARK: - Outlets
	@IBOutlet weak var titleTextField: UITextField!
	@IBOutlet weak var dateCardView: UIView!
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
    var watchlistIdToEdit: UUID?
    private var watchlistToEdit: Watchlist?
    
    // Location & Search
	private var locationSuggestions: [LocationService.LocationSuggestion] = []
	private var selectedLocation: LocationService.LocationData?
	
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
		let isDarkMode = traitCollection.userInterfaceStyle == .dark
		
			// Background & Styling
		view.backgroundColor = isDarkMode ? .systemBackground : .systemGray6
		titleTextField.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
		titleTextField.textColor = .label
		titleTextField.layer.cornerRadius = 12
		titleTextField.layer.masksToBounds = true
		styleSearchBar(locationSearchBar, isDarkMode: isDarkMode)
		suggestionsTableView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
		participantsTableView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
		styleCard(dateCardView, isDarkMode: isDarkMode)
		styleCard(locationOptionsContainer, isDarkMode: isDarkMode)
		
		if let inviteView = inviteContactsView {
			styleCard(inviteView, isDarkMode: isDarkMode, cornerRadius: 12, shadowRadius: 8, shadowOpacity: 0.05, shadowOffset: CGSize(width: 0, height: 2))
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

	private func styleSearchBar(_ searchBar: UISearchBar, isDarkMode: Bool) {
		let textField = searchBar.searchTextField
		textField.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
		textField.textColor = .label
		textField.layer.cornerRadius = 12
		textField.layer.masksToBounds = true
		textField.leftView?.tintColor = .secondaryLabel
	}

	private func styleCard(
		_ view: UIView,
		isDarkMode: Bool,
		cornerRadius: CGFloat = 20,
		shadowRadius: CGFloat = 12,
		shadowOpacity: Float = 0.08,
		shadowOffset: CGSize = CGSize(width: 0, height: 4)
	) {
		view.layer.cornerRadius = cornerRadius
		view.backgroundColor = isDarkMode ? .secondarySystemBackground : .white
		view.layer.shadowColor = UIColor.black.cgColor
		view.layer.shadowOpacity = isDarkMode ? 0 : shadowOpacity
		view.layer.shadowOffset = shadowOffset
		view.layer.shadowRadius = shadowRadius
		view.layer.masksToBounds = false
	}
	
	private func setupLocationServices() {
	}
	
	private func populateDataForEdit() {
		if let watchlist = watchlistToEdit {
			titleTextField.text = watchlist.title
			locationSearchBar.text = watchlist.locationDisplayName ?? watchlist.location
            if let start = watchlist.startDate { startDatePicker.date = start }
            if let end = watchlist.endDate { endDatePicker.date = end }
		}
	}
	
    private func configureInitialData() {
        if let id = watchlistIdToEdit {
            self.watchlistToEdit = manager.getWatchlist(by: id)
        }
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
		Task {
			do {
				let location = try await locationService.getCurrentLocation()
				updateLocationSelection(location)
			} catch {
				presentAlert(title: "Location Unavailable", message: "Please enable location services in Settings.")
			}
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
	private func updateLocationSelection(_ location: LocationService.LocationData) {
		locationSearchBar.text = location.displayName
		selectedLocation = location
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
	}
	
	private func updateLocationSelection(_ name: String) {
		locationSearchBar.text = name
		selectedLocation = nil
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
			watchlist.locationDisplayName = selectedLocation?.displayName ?? location
            watchlist.startDate = startDate
            watchlist.endDate = endDate
            
			navigationController?.popViewController(animated: true)
			return
		}
		
			// 2. Create New Watchlist
        manager.addWatchlist(title: title, location: location, startDate: startDate, endDate: endDate, type: watchlistType, locationDisplayName: selectedLocation?.displayName ?? location)
		
		navigationController?.popViewController(animated: true)
	}
	
		// MARK: - Helpers
	private func presentAlert(title: String, message: String) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}

// MARK: - CoreLocation Delegate
extension EditWatchlistDetailViewController: CLLocationManagerDelegate {
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}

// MARK: - TableView Delegate & DataSource
extension EditWatchlistDetailViewController: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return tableView == participantsTableView ? participants.count : locationSuggestions.count
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
			if traitCollection.userInterfaceStyle == .dark {
				cell.backgroundColor = .secondarySystemBackground
				cell.contentView.backgroundColor = .secondarySystemBackground
			}
			return cell
		} else {
			let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
			let item = locationSuggestions[indexPath.row]
			cell.textLabel?.text = item.fullText
			if traitCollection.userInterfaceStyle == .dark {
				cell.backgroundColor = .secondarySystemBackground
				cell.contentView.backgroundColor = .secondarySystemBackground
			}
			return cell
		}
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if tableView == suggestionsTableView {
			let item = locationSuggestions[indexPath.row]
			let query = item.fullText
			updateLocationSelection(query)
			
			Task {
				do {
					let location = try await locationService.geocode(query: query)
					// Use the user's selected text (query) for display name, but geocoded coordinates
					let finalLocation = LocationService.LocationData(
						displayName: query,
						lat: location.lat,
						lon: location.lon
					)
					await MainActor.run { self.updateLocationSelection(finalLocation) }
				} catch {
					await MainActor.run { self.updateLocationSelection(query) }
				}
			}
		}
	}
}

// MARK: - Search Delegates
extension EditWatchlistDetailViewController: UISearchBarDelegate, MKLocalSearchCompleterDelegate {
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		selectedLocation = nil
		if searchText.isEmpty {
			locationSuggestions = []
			suggestionsTableView.isHidden = true
		} else {
			Task {
				let results = await locationService.getAutocompleteSuggestions(for: searchText)
				await MainActor.run {
					self.locationSuggestions = results
					self.suggestionsTableView.isHidden = self.locationSuggestions.isEmpty
					self.suggestionsTableView.reloadData()
				}
			}
		}
	}
	
	func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		suggestionsTableView.isHidden = locationSuggestions.isEmpty
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchBar.resignFirstResponder()
		suggestionsTableView.isHidden = true
	}
	
	func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {}
	func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}

// MARK: - MapSelectionDelegate
extension EditWatchlistDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(name: String, lat: Double, lon: Double) {
        updateLocationSelection(LocationService.LocationData(displayName: name, lat: lat, lon: lon))
    }
}
// MARK: - UI Utilities
