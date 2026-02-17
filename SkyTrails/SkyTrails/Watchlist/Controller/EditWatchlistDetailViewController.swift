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
	
	// MARK: - Rule Configuration UI
	private var rulesContainerView: UIView!
	
	// Species Rule
	private var speciesRuleToggle: UISwitch!
	private var speciesRuleLabel: UILabel!
	private var shapeCollectionView: UICollectionView!
	private var availableShapes: [BirdShape] = []
	private var selectedShapeId: String?
	
	// Location Rule
	private var locationRuleToggle: UISwitch!
	private var locationRuleLabel: UILabel!
	private var locationRuleButton: UIButton!
	private var locationRuleInfoLabel: UILabel!
	private var selectedRuleLocation: CLLocationCoordinate2D?
	private var selectedRuleRadius: Double = 50.0
	private var selectedRuleLocationDisplayName: String?
	
	// Date Rule
	private var dateRuleToggle: UISwitch!
	private var dateRuleLabel: UILabel!
	private var dateRuleStartPicker: UIDatePicker!
	private var dateRuleEndPicker: UIDatePicker!
	
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
            self.watchlistToEdit = try? manager.getWatchlist(by: id)
        }
        initializeParticipants()
        populateDataForEdit()
        loadAvailableShapes()
        // Delay rules UI setup to ensure view hierarchy is ready
        DispatchQueue.main.async {
            self.setupRulesUI()
            self.populateRuleDataForEdit()
        }
    }
    
    // MARK: - Rules Setup
    private func loadAvailableShapes() {
        // Fetch shapes that have birds associated with them
        let allShapes = (try? manager.fetchAll(BirdShape.self)) ?? []
        let allBirds = manager.fetchAllBirds()
        let usedShapeIds = Set(allBirds.compactMap { $0.shape_id })
        availableShapes = allShapes.filter { usedShapeIds.contains($0.id) }
    }
    
    private func setupRulesUI() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        // Find the scroll view
        guard let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
            print("⚠️ Could not find scroll view")
            return
        }
        
        // Find the main stack view - it's the first arranged subview that's a stack view
        // The scroll view contains the content layout guide, frame layout guide, and content view
        let mainStackView: UIStackView
        if let stackView = scrollView.subviews.compactMap({ $0 as? UIStackView }).first {
            mainStackView = stackView
        } else if let stackView = scrollView.subviews.flatMap({ $0.subviews }).compactMap({ $0 as? UIStackView }).first {
            mainStackView = stackView
        } else {
            print("⚠️ Could not find stack view in scroll view")
            return
        }
        
        // Create rules container
        rulesContainerView = UIView()
        rulesContainerView.translatesAutoresizingMaskIntoConstraints = false
        rulesContainerView.backgroundColor = isDarkMode ? .secondarySystemBackground : .white
        rulesContainerView.layer.cornerRadius = 20
        rulesContainerView.layer.shadowColor = UIColor.black.cgColor
        rulesContainerView.layer.shadowOpacity = isDarkMode ? 0 : 0.08
        rulesContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        rulesContainerView.layer.shadowRadius = 12
        rulesContainerView.layer.masksToBounds = false
        
        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Auto-Assignment Rules"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        rulesContainerView.addSubview(titleLabel)
        
        // Stack view for rules
        let rulesStack = UIStackView()
        rulesStack.translatesAutoresizingMaskIntoConstraints = false
        rulesStack.axis = .vertical
        rulesStack.spacing = 20
        rulesStack.alignment = .fill
        rulesContainerView.addSubview(rulesStack)
        
        // Species Rule Section
        let speciesSection = createRuleSection(title: "Species Filter")
        speciesRuleToggle = UISwitch()
        speciesRuleToggle.addTarget(self, action: #selector(speciesRuleToggled), for: .valueChanged)
        addToggleToSection(section: speciesSection, toggle: speciesRuleToggle)
        
        // Shape collection view (hidden by default)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.itemSize = CGSize(width: 80, height: 100)
        
        shapeCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        shapeCollectionView.translatesAutoresizingMaskIntoConstraints = false
        shapeCollectionView.backgroundColor = .clear
        shapeCollectionView.showsHorizontalScrollIndicator = false
        shapeCollectionView.delegate = self
        shapeCollectionView.dataSource = self
        shapeCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "ShapeCell")
        shapeCollectionView.isHidden = true
        shapeCollectionView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        speciesSection.addArrangedSubview(shapeCollectionView)
        
        rulesStack.addArrangedSubview(speciesSection)
        
        // Location Rule Section
        let locationSection = createRuleSection(title: "Location Filter")
        locationRuleToggle = UISwitch()
        locationRuleToggle.addTarget(self, action: #selector(locationRuleToggled), for: .valueChanged)
        addToggleToSection(section: locationSection, toggle: locationRuleToggle)
        
        locationRuleButton = UIButton(type: .system)
        locationRuleButton.translatesAutoresizingMaskIntoConstraints = false
        locationRuleButton.setTitle("Select Location on Map", for: .normal)
        locationRuleButton.addTarget(self, action: #selector(didTapLocationRuleMap), for: .touchUpInside)
        locationRuleButton.isHidden = true
        locationSection.addArrangedSubview(locationRuleButton)
        
        locationRuleInfoLabel = UILabel()
        locationRuleInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        locationRuleInfoLabel.font = .systemFont(ofSize: 14)
        locationRuleInfoLabel.textColor = .secondaryLabel
        locationRuleInfoLabel.numberOfLines = 0
        locationRuleInfoLabel.isHidden = true
        locationSection.addArrangedSubview(locationRuleInfoLabel)
        
        rulesStack.addArrangedSubview(locationSection)
        
        // Date Rule Section
        let dateSection = createRuleSection(title: "Date Filter")
        dateRuleToggle = UISwitch()
        dateRuleToggle.addTarget(self, action: #selector(dateRuleToggled), for: .valueChanged)
        addToggleToSection(section: dateSection, toggle: dateRuleToggle)
        
        let datePickersStack = UIStackView()
        datePickersStack.translatesAutoresizingMaskIntoConstraints = false
        datePickersStack.axis = .vertical
        datePickersStack.spacing = 12
        datePickersStack.isHidden = true
        
        let startLabel = UILabel()
        startLabel.text = "Start Date"
        startLabel.font = .systemFont(ofSize: 14, weight: .medium)
        datePickersStack.addArrangedSubview(startLabel)
        
        dateRuleStartPicker = UIDatePicker()
        dateRuleStartPicker.datePickerMode = .date
        datePickersStack.addArrangedSubview(dateRuleStartPicker)
        
        let endLabel = UILabel()
        endLabel.text = "End Date"
        endLabel.font = .systemFont(ofSize: 14, weight: .medium)
        datePickersStack.addArrangedSubview(endLabel)
        
        dateRuleEndPicker = UIDatePicker()
        dateRuleEndPicker.datePickerMode = .date
        datePickersStack.addArrangedSubview(dateRuleEndPicker)
        
        dateSection.addArrangedSubview(datePickersStack)
        datePickersStack.accessibilityIdentifier = "DatePickersStack"
        
        rulesStack.addArrangedSubview(dateSection)
        
        // Constraints for container subviews
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: rulesContainerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: rulesContainerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: rulesContainerView.trailingAnchor, constant: -16),
            
            rulesStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            rulesStack.leadingAnchor.constraint(equalTo: rulesContainerView.leadingAnchor, constant: 16),
            rulesStack.trailingAnchor.constraint(equalTo: rulesContainerView.trailingAnchor, constant: -16),
            rulesStack.bottomAnchor.constraint(equalTo: rulesContainerView.bottomAnchor, constant: -16)
        ])
        
        // Insert into the scroll view's stack view at the appropriate position (after date section)
        if let dateSectionIndex = mainStackView.arrangedSubviews.firstIndex(where: { view -> Bool in
            // Find the date section view (it has a label with "Date" text)
            if let label = view.subviews.first(where: { $0 is UILabel }) as? UILabel {
                return label.text == "Date"
            }
            return false
        }) {
            // Insert after the date section and its corresponding view
            let insertIndex = min(dateSectionIndex + 2, mainStackView.arrangedSubviews.count)
            mainStackView.insertArrangedSubview(rulesContainerView, at: insertIndex)
        } else {
            // Fallback: add at the end
            mainStackView.addArrangedSubview(rulesContainerView)
        }
    }
    
    private func createRuleSection(title: String) -> UIStackView {
        let section = UIStackView()
        section.translatesAutoresizingMaskIntoConstraints = false
        section.axis = .vertical
        section.spacing = 12
        section.alignment = .fill
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .equalSpacing
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        headerStack.addArrangedSubview(label)
        
        section.addArrangedSubview(headerStack)
        
        return section
    }
    
    private func addToggleToSection(section: UIStackView, toggle: UISwitch) {
        if let header = section.arrangedSubviews.first as? UIStackView {
            header.addArrangedSubview(toggle)
        }
    }
    
    @objc private func speciesRuleToggled() {
        shapeCollectionView.isHidden = !speciesRuleToggle.isOn
        if speciesRuleToggle.isOn {
            shapeCollectionView.reloadData()
        }
    }
    
    @objc private func locationRuleToggled() {
        locationRuleButton.isHidden = !locationRuleToggle.isOn
        locationRuleInfoLabel.isHidden = !locationRuleToggle.isOn
    }
    
    @objc private func dateRuleToggled() {
        if let dateSection = dateRuleToggle.superview?.superview as? UIStackView,
           let datePickersStack = dateSection.arrangedSubviews.last(where: { $0.accessibilityIdentifier == "DatePickersStack" }) {
            datePickersStack.isHidden = !dateRuleToggle.isOn
        }
    }
    
    @objc private func didTapLocationRuleMap() {
        let mapVC = WatchlistLocationRuleMapViewController()
        mapVC.delegate = self
        navigationController?.pushViewController(mapVC, animated: true)
    }
    
    private func populateRuleDataForEdit() {
        guard let watchlist = watchlistToEdit else { return }
        
        // Ensure UI is set up before trying to populate it
        guard speciesRuleToggle != nil else {
            print("⚠️ Rules UI not set up yet, skipping populateRuleDataForEdit")
            return
        }
        
        // Species Rule
        speciesRuleToggle.isOn = watchlist.speciesRuleEnabled
        selectedShapeId = watchlist.speciesRuleShapeId
        shapeCollectionView.isHidden = !watchlist.speciesRuleEnabled
        if watchlist.speciesRuleEnabled {
            shapeCollectionView.reloadData()
        }
        
        // Location Rule
        locationRuleToggle.isOn = watchlist.locationRuleEnabled
        locationRuleButton.isHidden = !watchlist.locationRuleEnabled
        locationRuleInfoLabel.isHidden = !watchlist.locationRuleEnabled
        if let lat = watchlist.locationRuleLat, let lon = watchlist.locationRuleLon {
            selectedRuleLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedRuleRadius = watchlist.locationRuleRadiusKm
            
            // Use stored display name if available, otherwise will geocode
            if let displayName = watchlist.locationRuleDisplayName {
                selectedRuleLocationDisplayName = displayName
                locationRuleInfoLabel.text = "Within \(Int(selectedRuleRadius))km of \(displayName)"
            } else {
                locationRuleInfoLabel.text = "Within \(Int(selectedRuleRadius))km of selected location"
                // Reverse geocode to get the name
                Task {
                    if let name = await locationService.reverseGeocode(lat: lat, lon: lon) {
                        await MainActor.run {
                            self.selectedRuleLocationDisplayName = name
                            self.locationRuleInfoLabel.text = "Within \(Int(self.selectedRuleRadius))km of \(name)"
                            self.watchlistToEdit?.locationRuleDisplayName = name
                        }
                    }
                }
            }
        }
        
        // Date Rule
        dateRuleToggle.isOn = watchlist.dateRuleEnabled
        if let startDate = watchlist.dateRuleStartDate {
            dateRuleStartPicker.date = startDate
        }
        if let endDate = watchlist.dateRuleEndDate {
            dateRuleEndPicker.date = endDate
        }
        // Show/hide date pickers based on toggle
        if let dateSection = dateRuleToggle.superview?.superview as? UIStackView,
           let datePickersStack = dateSection.arrangedSubviews.last(where: { $0.accessibilityIdentifier == "DatePickersStack" }) {
            datePickersStack.isHidden = !watchlist.dateRuleEnabled
        }
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
            
            // Save rule configuration
            watchlist.speciesRuleEnabled = speciesRuleToggle.isOn
            watchlist.speciesRuleShapeId = speciesRuleToggle.isOn ? selectedShapeId : nil
            
            watchlist.locationRuleEnabled = locationRuleToggle.isOn
            if locationRuleToggle.isOn, let ruleLocation = selectedRuleLocation {
                watchlist.locationRuleLat = ruleLocation.latitude
                watchlist.locationRuleLon = ruleLocation.longitude
                watchlist.locationRuleRadiusKm = selectedRuleRadius
                watchlist.locationRuleDisplayName = selectedRuleLocationDisplayName
            } else {
                watchlist.locationRuleLat = nil
                watchlist.locationRuleLon = nil
                watchlist.locationRuleDisplayName = nil
            }
            
            watchlist.dateRuleEnabled = dateRuleToggle.isOn
            if dateRuleToggle.isOn {
                watchlist.dateRuleStartDate = dateRuleStartPicker.date
                watchlist.dateRuleEndDate = dateRuleEndPicker.date
            } else {
                watchlist.dateRuleStartDate = nil
                watchlist.dateRuleEndDate = nil
            }
            
			navigationController?.popViewController(animated: true)
			return
		}
		
			// 2. Create New Watchlist
        do {
            try manager.addWatchlist(
                title: title,
                location: location,
                startDate: startDate,
                endDate: endDate,
                type: watchlistType,
                locationDisplayName: selectedLocation?.displayName ?? location
            )
            navigationController?.popViewController(animated: true)
        } catch {
            print("❌ [EditWatchlistDetailViewController] Failed to add watchlist: \(error)")
            presentAlert(title: "Save Failed", message: error.localizedDescription)
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

// MARK: - WatchlistLocationRuleDelegate
extension EditWatchlistDetailViewController: WatchlistLocationRuleDelegate {
    func didSelectLocationRule(location: CLLocationCoordinate2D, radiusKm: Double, displayName: String) {
        selectedRuleLocation = location
        selectedRuleRadius = radiusKm
        selectedRuleLocationDisplayName = displayName
        locationRuleInfoLabel.text = "Within \(Int(radiusKm))km of \(displayName)"
    }
}

// MARK: - UICollectionView Delegate & DataSource
extension EditWatchlistDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return availableShapes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ShapeCell", for: indexPath)
        let shape = availableShapes[indexPath.item]
        
        // Configure cell
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
        
        let isSelected = (shape.id == selectedShapeId)
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        if isSelected {
            cell.contentView.layer.borderWidth = 3
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(isDarkMode ? 0.24 : 0.10)
        } else {
            cell.contentView.layer.borderWidth = 1
            cell.contentView.layer.borderColor = (isDarkMode ? UIColor.systemGray3 : UIColor.systemGray4).cgColor
            cell.contentView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        }
        
        // Image
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: shape.icon)
        cell.contentView.addSubview(imageView)
        
        // Label
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = shape.name
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        cell.contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            imageView.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 40),
            imageView.heightAnchor.constraint(equalToConstant: 40),
            
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -4),
            label.bottomAnchor.constraint(lessThanOrEqualTo: cell.contentView.bottomAnchor, constant: -4)
        ])
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let shape = availableShapes[indexPath.item]
        selectedShapeId = shape.id
        collectionView.reloadData()
    }
}

// MARK: - UI Utilities
