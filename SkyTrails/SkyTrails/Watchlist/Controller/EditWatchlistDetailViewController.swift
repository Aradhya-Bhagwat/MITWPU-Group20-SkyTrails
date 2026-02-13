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
	
    // Rules Section
    @IBOutlet weak var rulesContainerView: UIView!
    @IBOutlet weak var rulesHeaderButton: UIButton!  // Collapsible header
    @IBOutlet weak var rulesContentStack: UIStackView!  // Hidden/shown
    
    // Family/Shape Rule
    @IBOutlet weak var familyShapeRuleView: UIView!
    @IBOutlet weak var familyShapeToggle: UISwitch!
    @IBOutlet weak var familyShapeConfigView: UIView!
    @IBOutlet weak var familyShapeSelectionLabel: UILabel!
    
    // Date Rule
    @IBOutlet weak var dateRuleView: UIView!
    @IBOutlet weak var dateToggle: UISwitch!
    
    // Location Rule
    @IBOutlet weak var locationRuleView: UIView!
    @IBOutlet weak var locationToggle: UISwitch!
    @IBOutlet weak var locationConfigView: UIView!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!
    @IBOutlet weak var radiusMapView: MKMapView!
    
		// MARK: - Properties
	var watchlistType: WatchlistType = .custom
	
    // Edit Mode Data
    var watchlistIdToEdit: UUID?
    private var watchlistToEdit: Watchlist?
    
    // Rule State
    private var rulesExpanded = true
    private var selectedFamilies: [String] = []
    private var selectedShapes: [String] = []
    private var locationRadius: Double = 50.0
    
    // Rule objects
    private var familyShapeRule: WatchlistRule?
    private var dateRule: WatchlistRule?
    private var locationRule: WatchlistRule?
    
    // Location & Search
	private var locationSuggestions: [LocationService.LocationSuggestion] = []
	private var selectedLocation: LocationService.LocationData?
	
		// Internal State
	private var participants: [Participant] = []
	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
        setupRulesSection()
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
    
    // MARK: - Rules Logic
    
    private func setupRulesSection() {
        // Guard against outlets not being connected yet if view hasn't loaded fully
        guard let container = rulesContainerView else { return }
        
        styleCard(container, isDarkMode: traitCollection.userInterfaceStyle == .dark)
        
        // Setup collapsible header
        rulesHeaderButton.addTarget(self, action: #selector(toggleRulesSection), for: .touchUpInside)
        
        // Setup rule toggles
        familyShapeToggle.addTarget(self, action: #selector(familyShapeToggleChanged), for: .valueChanged)
        dateToggle.addTarget(self, action: #selector(dateToggleChanged), for: .valueChanged)
        locationToggle.addTarget(self, action: #selector(locationToggleChanged), for: .valueChanged)
        
        // Setup configure button
        let configureTap = UITapGestureRecognizer(target: self, action: #selector(showFamilyShapeSelection))
        familyShapeConfigView.addGestureRecognizer(configureTap)
        familyShapeConfigView.isUserInteractionEnabled = true
        
        // Setup radius slider
        radiusSlider.minimumValue = 10
        radiusSlider.maximumValue = 200
        radiusSlider.value = Float(locationRadius)
        radiusSlider.addTarget(self, action: #selector(radiusSliderChanged), for: .valueChanged)
        
        updateRulesVisibility()
    }

    private func updateRulesVisibility() {
        guard let dateView = dateRuleView else { return }
        
        // Hide date rule if no dates
        let hasDates = (watchlistToEdit?.startDate != nil || watchlistToEdit?.endDate != nil) || (startDatePicker.date != Date.distantPast)
        // Check if dates are set in UI (since we might be creating new)
        // For new watchlist, dates are always in pickers, so effectively always show unless explicitly cleared?
        // Let's assume always visible for now unless dates are nil in model (edit mode)
        // Or simpler: always show date rule option, but maybe disable if logic dictates?
        // Plan says: "Date rule hidden if no dates set"
        // Let's rely on model or current picker values
        
        // Hide location rule if no location
        // locationRuleView.isHidden = (locationSearchBar.text?.isEmpty ?? true)
        
        // Update family/shape config view
        familyShapeConfigView.isHidden = !familyShapeToggle.isOn
        locationConfigView.isHidden = !locationToggle.isOn
    }

    private func loadExistingRules() {
        guard let watchlist = watchlistToEdit,
              let rules = watchlist.rules else {
            // New watchlist - default all ON
            familyShapeToggle.isOn = true
            dateToggle.isOn = true
            locationToggle.isOn = true
            return
        }
        
        // Load existing rules
        for rule in rules {
            switch rule.rule_type {
            case .species_family:
                familyShapeRule = rule
                familyShapeToggle.isOn = rule.is_active
                if let jsonData = rule.parameters_json.data(using: .utf8),
                   let params = try? JSONDecoder().decode(FamilyShapeRuleParams.self, from: jsonData) {
                    selectedFamilies = params.families
                    selectedShapes = params.shapes
                    updateFamilyShapeLabel()
                }
            case .date_range:
                dateRule = rule
                dateToggle.isOn = rule.is_active
            case .location:
                locationRule = rule
                locationToggle.isOn = rule.is_active
                if let jsonData = rule.parameters_json.data(using: .utf8),
                   let params = try? JSONDecoder().decode(LocationRuleParams.self, from: jsonData) {
                    locationRadius = params.radiusKm
                    radiusSlider.value = Float(locationRadius)
                    updateRadiusLabel()
                    updateRadiusMap()
                }
            default:
                break
            }
        }
    }
    
    @objc private func toggleRulesSection() {
        rulesExpanded.toggle()
        rulesContentStack.isHidden = !rulesExpanded
        
        // Rotate chevron icon
        UIView.animate(withDuration: 0.3) {
            let rotation = self.rulesExpanded ? 0 : -CGFloat.pi / 2
            self.rulesHeaderButton.imageView?.transform = CGAffineTransform(rotationAngle: rotation)
        }
    }

    @objc private func familyShapeToggleChanged() {
        familyShapeConfigView.isHidden = !familyShapeToggle.isOn
    }

    @objc private func dateToggleChanged() {
        // No action needed until save
    }

    @objc private func locationToggleChanged() {
        locationConfigView.isHidden = !locationToggle.isOn
    }

    @objc private func showFamilyShapeSelection() {
        // Load from Storyboard since we added the scene there
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "FamilyShapeSelectionViewController") as? FamilyShapeSelectionViewController else { return }
        
        vc.selectedFamilies = Set(selectedFamilies)
        vc.selectedShapes = Set(selectedShapes)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func radiusSliderChanged() {
        locationRadius = Double(radiusSlider.value)
        updateRadiusLabel()
        updateRadiusMap()
    }

    private func updateRadiusLabel() {
        radiusLabel.text = "\(Int(locationRadius)) km"
    }

    private func updateRadiusMap() {
        // Use current location or watchlist location
        // If editing, use watchlist.lat/lon
        // If new or changed, use selectedLocation
        
        var center: CLLocationCoordinate2D?
        
        if let sel = selectedLocation {
            center = CLLocationCoordinate2D(latitude: sel.lat, longitude: sel.lon)
        } else if let wl = watchlistToEdit, let lat = wl.lat, let lon = wl.lon {
            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        guard let mapCenter = center else { return }
        
        let region = MKCoordinateRegion(
            center: mapCenter,
            latitudinalMeters: locationRadius * 2000,
            longitudinalMeters: locationRadius * 2000
        )
        radiusMapView.setRegion(region, animated: true)
        
        // Add circle overlay
        radiusMapView.removeOverlays(radiusMapView.overlays)
        let circle = MKCircle(center: mapCenter, radius: locationRadius * 1000)
        radiusMapView.addOverlay(circle)
    }

    private func applyRulesRetroactively() {
        guard let watchlistId = watchlistToEdit?.id else { return }
        
        Task {
            await WatchlistManager.shared.applyRulesRetroactively(to: watchlistId)
            
            await MainActor.run {
                let alert = UIAlertController(
                    title: "Rules Applied",
                    message: "Auto-categorization rules have been updated.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
    
    private func updateFamilyShapeLabel() {
        let total = selectedFamilies.count + selectedShapes.count
        if total == 0 {
            familyShapeSelectionLabel.text = "Tap to configure"
        } else {
            let preview = (selectedFamilies + selectedShapes).prefix(3).joined(separator: ", ")
            familyShapeSelectionLabel.text = "\(total) selected: \(preview)..."
        }
    }
    
    private func saveRules(for watchlist: Watchlist) async {
        let manager = WatchlistManager.shared
        
        // Family/Shape Rule
        if familyShapeToggle.isOn && (!selectedFamilies.isEmpty || !selectedShapes.isEmpty) {
            let params = FamilyShapeRuleParams(families: selectedFamilies, shapes: selectedShapes)
            try? manager.addOrUpdateRule(
                to: watchlist.id,
                type: .species_family,
                parameters: params,
                existingRule: familyShapeRule
            )
        } else if let rule = familyShapeRule {
            rule.is_active = false
        }
        
        // Date Rule
        if dateToggle.isOn && watchlist.startDate != nil && watchlist.endDate != nil {
            let params = DateRangeRuleParams(startDate: watchlist.startDate!, endDate: watchlist.endDate!)
            try? manager.addOrUpdateRule(
                to: watchlist.id,
                type: .date_range,
                parameters: params,
                existingRule: dateRule
            )
        } else if let rule = dateRule {
            rule.is_active = false
        }
        
        // Location Rule
        if locationToggle.isOn && watchlist.lat != nil && watchlist.lon != nil {
            let params = LocationRuleParams(radiusKm: locationRadius)
            try? manager.addOrUpdateRule(
                to: watchlist.id,
                type: .location,
                parameters: params,
                existingRule: locationRule
            )
        } else if let rule = locationRule {
            rule.is_active = false
        }
    }
    
    // MARK: - Map Delegate Update for Radius
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 1
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    private func configureInitialData() {
        if let id = watchlistIdToEdit {
            self.watchlistToEdit = manager.getWatchlist(by: id)
        }
        initializeParticipants()
        populateDataForEdit()
        loadExistingRules()
        updateRulesVisibility()
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
        let locDisplayName = selectedLocation?.displayName ?? location
		
        Task {
            // 1. Update Existing Watchlist
            if let watchlist = watchlistToEdit {
                // Direct update on SwiftData object
                watchlist.title = title
                watchlist.location = location
                watchlist.locationDisplayName = locDisplayName
                watchlist.startDate = startDate
                watchlist.endDate = endDate
                
                await saveRules(for: watchlist)
                
                // Apply rules retroactively to catch any existing birds that match new rules
                await manager.applyRulesRetroactively(to: watchlist.id)
                
                await MainActor.run {
                    navigationController?.popViewController(animated: true)
                }
                return
            }
            
            // 2. Create New Watchlist
            let newWatchlist = manager.addWatchlist(
                title: title,
                location: location,
                startDate: startDate,
                endDate: endDate,
                type: watchlistType,
                locationDisplayName: locDisplayName
            )
            
            await saveRules(for: newWatchlist)
            
            // Apply rules retroactively to catch any existing birds that match new rules
            await manager.applyRulesRetroactively(to: newWatchlist.id)
            
            await MainActor.run {
                navigationController?.popViewController(animated: true)
            }
        }
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
// MARK: - FamilyShapeSelectionDelegate
extension EditWatchlistDetailViewController: FamilyShapeSelectionDelegate {
    func didSelectFamiliesAndShapes(families: [String], shapes: [String]) {
        selectedFamilies = families
        selectedShapes = shapes
        updateFamilyShapeLabel()
    }
}

