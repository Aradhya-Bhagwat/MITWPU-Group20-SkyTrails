
import UIKit
import CoreLocation
import MapKit
import SwiftData
struct Participant {
	let name: String
	let imageName: String
}

@MainActor
class EditWatchlistDetailViewController: UIViewController {

	private let manager = WatchlistManager.shared
	private let repository: WatchlistRepository = WatchlistManager.shared
	private let locationService = LocationService.shared
	@IBOutlet weak var titleTextField: UITextField!
	@IBOutlet weak var dateCardView: UIView!
	@IBOutlet weak var locationSearchBar: UISearchBar!
	@IBOutlet weak var locationOptionsContainer: UIView!
	@IBOutlet weak var startDatePicker: UIDatePicker!
	@IBOutlet weak var endDatePicker: UIDatePicker!
	@IBOutlet weak var inviteContactsView: UIView!
	@IBOutlet weak var suggestionsTableView: UITableView!
	@IBOutlet weak var participantsTableView: UITableView!
	@IBOutlet private weak var speciesHeaderStack: UIStackView!
	@IBOutlet private weak var speciesInfoButton: UIButton!
	@IBOutlet private weak var rulesContainerView: UIView!
	@IBOutlet private weak var speciesRuleToggle: UISwitch!
	@IBOutlet private weak var shapeCollectionView: UICollectionView!
	@IBOutlet private weak var clearWatchlistButton: UIButton!
	@IBOutlet private weak var deleteWatchlistButton: UIButton!
	var watchlistType: WatchlistType = .custom
    var watchlistIdToEdit: UUID?
    private var watchlistToEdit: Watchlist?
	private var locationSuggestions: [LocationService.LocationSuggestion] = []
	private var selectedLocation: LocationService.LocationData?
	private var participants: [Participant] = []
	private var availableShapes: [BirdShape] = []
	private var selectedShapeId: String?
    private var existingLocationRuleData: (lat: Double, lon: Double, radiusKm: Double)?
    private var existingSpeciesShapeId: String?
    
    private var selectedRuleRadius: Double = 50.0

	@IBOutlet weak var locationInputToggle: UISwitch!
    @IBOutlet weak var dateInputToggle: UISwitch!

	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupLocationServices()
		configureInitialData()
		configureRulesSection()
		populateRuleDataForEdit()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		IdentificationTooltipManager.shared.scheduleStepByStepTooltips(in: self.view, steps: [
			(message: "Enter a name for your watchlist.",
			 targetProvider: { [weak self] in self?.titleTextField }),
			(message: "Set date range.",
			 targetProvider: { [weak self] in self?.startDatePicker }),
			(message: "Set a location filter (optional).",
			 targetProvider: { [weak self] in self?.locationSearchBar }),
			(message: "Filter by bird shape (optional).",
			 targetProvider: { [weak self] in self?.speciesRuleToggle }),
			(message: "Tap Save when you're done.",
			 targetProvider: { [weak self] in
				 self?.navigationItem.rightBarButtonItems?.first?.value(forKey: "view") as? UIView
			 })
		])
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		IdentificationTooltipManager.shared.cancelTooltip()
	}
    
    @IBAction private func dateInputToggled() {
		IdentificationTooltipManager.shared.cancelTooltip()
        UIView.animate(withDuration: 0.3) {
            self.dateCardView.isHidden = false
            self.dateCardView.alpha = 1.0
        }
    }
    
    @IBAction private func locationInputToggled() {
		IdentificationTooltipManager.shared.cancelTooltip()
        UIView.animate(withDuration: 0.3) {
            self.locationSearchBar.isHidden = false
            self.locationOptionsContainer.isHidden = false
            self.locationSearchBar.alpha = 1.0
            self.locationOptionsContainer.alpha = 1.0
        }
    }
    
	private func setupUI() {
		let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
		navigationItem.rightBarButtonItem = saveButton
		self.title = (watchlistIdToEdit == nil) ? "Create Watchlist" : "Watchlist Settings"
		let isDarkMode = traitCollection.userInterfaceStyle == .dark
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
		inviteContactsView.isHidden = (watchlistType != .shared)
		suggestionsTableView.isHidden = true
		participantsTableView.delegate = self
		participantsTableView.dataSource = self
		suggestionsTableView.delegate = self
		suggestionsTableView.dataSource = self
		locationSearchBar.delegate = self
		speciesInfoButton.tintColor = .systemBlue

		wireInfoButtons()
		
		setupLocationOptionsInteractions()
	}

	private func wireInfoButtons() {
		if let dateInfoButton = view.viewWithTag(12748140) as? UIButton {
			dateInfoButton.addTarget(self, action: #selector(didTapDateInfo), for: .touchUpInside)
		}
		wireInfoButtons(in: view)
	}

	private func wireInfoButtons(in root: UIView) {
		if let stack = root as? UIStackView {
			let labels = stack.arrangedSubviews.compactMap { $0 as? UILabel }
			let buttons = stack.arrangedSubviews.compactMap { $0 as? UIButton }
			if let button = buttons.first {
				if labels.contains(where: { ($0.text ?? "").localizedCaseInsensitiveContains("date") }) {
					button.addTarget(self, action: #selector(didTapDateInfo), for: .touchUpInside)
				}
				if labels.contains(where: { ($0.text ?? "").localizedCaseInsensitiveContains("location") }) {
					button.addTarget(self, action: #selector(didTapLocationInfo), for: .touchUpInside)
				}
			}
		}

		for subview in root.subviews {
			wireInfoButtons(in: subview)
		}
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
    }
    private func loadAvailableShapes() {
        let descriptor = FetchDescriptor<BirdShape>(sortBy: [SortDescriptor(\.name)])
        let allShapes = (try? manager.fetchAll(BirdShape.self, descriptor: descriptor)) ?? []
        let allBirds = manager.fetchAllBirds()
        let usedShapeIds = Set(allBirds.compactMap { $0.shape?.bird_shape_id ?? $0.shape_id })
        availableShapes = allShapes.filter { usedShapeIds.contains($0.bird_shape_id) }
    }

	private func configureRulesSection() {
		let isDarkMode = traitCollection.userInterfaceStyle == .dark
		styleCard(rulesContainerView, isDarkMode: isDarkMode)
		shapeCollectionView.delegate = self
		shapeCollectionView.dataSource = self
		shapeCollectionView.backgroundColor = .clear
		shapeCollectionView.showsHorizontalScrollIndicator = false
		if let layout = shapeCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
			layout.scrollDirection = .horizontal
			layout.minimumInteritemSpacing = 12
			layout.minimumLineSpacing = 12
			layout.itemSize = CGSize(width: 80, height: 100)
		}

		let actionButtons = [clearWatchlistButton, deleteWatchlistButton]
		actionButtons.forEach { button in
			button?.layer.cornerRadius = 12
			button?.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
			button?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
			button?.setTitleColor(.systemRed, for: .normal)
		}

		let isEditingWatchlist = (watchlistIdToEdit != nil)
		clearWatchlistButton.isHidden = !isEditingWatchlist
		deleteWatchlistButton.isHidden = !isEditingWatchlist
		speciesRuleToggle.isOn = false
		rulesContainerView.isHidden = true
		rulesContainerView.alpha = 0.0
	}

    @IBAction private func didTapDateInfo() {
        let message = "Temporal Bounds: Add birds typically seen during a specific time of year."
        let alert = UIAlertController(title: "About Date Filter", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }

    @IBAction private func didTapLocationInfo() {
        let message = "Region Boundaries: Add birds frequently spotted in a specific area."
        let alert = UIAlertController(title: "About Location Filter", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }

    @objc private func didTapSpeciesInfo() {
        let message = "Species Inclusion: Add all birds of a certain shape."
        let alert = UIAlertController(title: "About Species Filter", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }

    @objc private func speciesRuleToggled() {
        UIView.animate(withDuration: 0.3) {
            self.rulesContainerView.isHidden = !self.speciesRuleToggle.isOn
            self.rulesContainerView.alpha = self.speciesRuleToggle.isOn ? 1.0 : 0.0
        }
        if speciesRuleToggle.isOn {
            shapeCollectionView.reloadData()
        }
    }
    
    @objc private func didTapClearWatchlist() {
        guard let watchlist = watchlistToEdit else { return }
        
        let alert = UIAlertController(
            title: "Clear Watchlist",
            message: "Remove all birds from '\(watchlist.title ?? "this watchlist")'? The watchlist settings will be saved.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive, handler: { [weak self] _ in
            Task {
                do {
                    try self?.manager.clearWatchlist(id: watchlist.watchlist_id)
                    self?.navigationController?.popViewController(animated: true)
                } catch {
                    self?.presentAlert(title: "Clear Failed", message: error.localizedDescription)
                }
            }
        }))
        
        present(alert, animated: true)
    }

	@objc private func didTapDeleteWatchlist() {
		guard let watchlist = watchlistToEdit else { return }

		let alert = UIAlertController(
			title: "Delete Watchlist",
			message: "Permanently delete '\(watchlist.title ?? "this watchlist")'? This cannot be undone.",
			preferredStyle: .alert
		)

		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
			Task {
				do {
					try await self?.manager.deleteWatchlist(id: watchlist.watchlist_id)
					self?.navigateToWatchlistHomeAfterDelete()
				} catch {
					self?.presentAlert(title: "Delete Failed", message: error.localizedDescription)
				}
			}
		}))

		present(alert, animated: true)
	}

    private func navigateToWatchlistHomeAfterDelete() {
        guard let nav = navigationController else { return }

        if let homeVC = nav.viewControllers.first(where: { $0 is WatchlistHomeViewController }) {
            nav.popToViewController(homeVC, animated: true)
        } else {
            nav.popToRootViewController(animated: true)
        }
    }
    
    private func populateRuleDataForEdit() {
        guard let watchlist = watchlistToEdit else { return }
        guard speciesRuleToggle != nil else {
            return
        }
        
        let existingRules = (watchlist.rules ?? []).filter { $0.deleted_at == nil }
        
        if let speciesRule = existingRules.first(where: { $0.rule_type == .species_family }),
           let shapeId = speciesRule.shape_id {
            speciesRuleToggle.isOn = speciesRule.is_active
            selectedShapeId = shapeId
            existingSpeciesShapeId = shapeId
            rulesContainerView.isHidden = !speciesRuleToggle.isOn
            rulesContainerView.alpha = speciesRuleToggle.isOn ? 1.0 : 0.0
            shapeCollectionView.reloadData()
        } else {
            speciesRuleToggle.isOn = false
            selectedShapeId = nil
            existingSpeciesShapeId = nil
            rulesContainerView.isHidden = true
            rulesContainerView.alpha = 0.0
        }
        
        if let locationRule = existingRules.first(where: { $0.rule_type == .location }),
           let lat = locationRule.lat,
           let lon = locationRule.lon {
            locationInputToggle.isOn = locationRule.is_active
            selectedRuleRadius = locationRule.radius_km ?? 50.0
            existingLocationRuleData = (lat, lon, selectedRuleRadius)
            selectedLocation = LocationService.LocationData(displayName: watchlist.locationDisplayName ?? watchlist.location ?? "", lat: lat, lon: lon)
            locationSearchBar.text = selectedLocation?.displayName
            
            locationInputToggled()
        } else {
            locationInputToggle.isOn = false
            existingLocationRuleData = nil
            locationInputToggled()
        }
        
        if let dateRule = existingRules.first(where: { $0.rule_type == .date_range }),
           let startDate = dateRule.start_date,
           let endDate = dateRule.end_date {
            dateInputToggle.isOn = dateRule.is_active
            startDatePicker.date = startDate
            endDatePicker.date = endDate
            
            dateInputToggled()
        } else {
            dateInputToggle.isOn = false
            dateInputToggled()
        }
    }

	
	private func initializeParticipants() {
        if watchlistType == .shared {
            self.participants = [Participant(name: "You", imageName: "person.circle.fill")]
        } else {
            self.participants = [Participant(name: "You", imageName: "person.circle.fill")]
        }
		participantsTableView.reloadData()
	}
	private func setupLocationOptionsInteractions() {
		guard let container = locationOptionsContainer,
			  let mainStack = container.subviews.first as? UIStackView else { return }
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
		
        activityVC.completionWithItemsHandler = { (_, completed, _, _) in
        }
		
		present(activityVC, animated: true)
	}
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
	@objc private func didTapSave() {
		IdentificationTooltipManager.shared.cancelTooltip()
		guard let title = titleTextField.text, !title.isEmpty else {
			presentAlert(title: "Missing Info", message: "Please enter a title.")
			return
		}
		
		let location = locationSearchBar.text ?? "Unknown"
		let startDate = startDatePicker.date
		let endDate = endDatePicker.date
		
		do {
            let locationDisplayName = selectedLocation?.displayName ?? location
            let watchlistId: UUID
            
            if let watchlist = watchlistToEdit {
                watchlistId = watchlist.watchlist_id
                try manager.updateWatchlist(
                    id: watchlist.watchlist_id,
                    title: title,
                    location: location,
                    locationDisplayName: locationDisplayName,
                    startDate: startDate,
                    endDate: endDate
                )
            } else {
                watchlistId = try manager.addWatchlist(
                    title: title,
                    location: location,
                    startDate: startDate,
                    endDate: endDate,
                    type: watchlistType,
                    locationDisplayName: locationDisplayName
                )
            }
            
            try saveRules(for: watchlistId)
            navigationController?.popViewController(animated: true)
        } catch {
            presentAlert(title: "Save Failed", message: error.localizedDescription)
        }
	}
    
    private func saveRules(for watchlistId: UUID) throws {
        let speciesResult = manager.ruleAssemblyService.assembleSpeciesRule(
            selectedShapeId: selectedShapeId,
            existingShapeId: existingSpeciesShapeId,
            isActive: speciesRuleToggle.isOn
        )
        try manager.upsertRule(
            watchlistId: watchlistId,
            type: .species_family,
            parameters: speciesResult.parameters,
            isActive: speciesResult.isActive
        )
        
        let locationResult = manager.ruleAssemblyService.assembleLocationRule(
            selectedLocation: selectedLocation,
            existingData: existingLocationRuleData,
            selectedRadius: selectedRuleRadius,
            isActive: locationInputToggle.isOn
        )
        try manager.upsertRule(
            watchlistId: watchlistId,
            type: .location,
            parameters: locationResult.parameters,
            isActive: locationResult.isActive
        )
        
        let dateResult = manager.ruleAssemblyService.assembleDateRule(
            startDate: startDatePicker.date,
            endDate: endDatePicker.date,
            isActive: dateInputToggle.isOn
        )
        try manager.upsertRule(
            watchlistId: watchlistId,
            type: .date_range,
            parameters: dateResult.parameters,
            isActive: dateResult.isActive
        )
    }
	private func presentAlert(title: String, message: String) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
extension EditWatchlistDetailViewController: CLLocationManagerDelegate {
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}
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
extension EditWatchlistDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(name: String, lat: Double, lon: Double) {
        updateLocationSelection(LocationService.LocationData(displayName: name, lat: lat, lon: lon))
    }
}

extension EditWatchlistDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return availableShapes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "ShapeCell",
            for: indexPath
        ) as? WatchlistShapeCollectionViewCell else {
            return UICollectionViewCell()
        }
        let shape = availableShapes[indexPath.item]
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
        
        let isSelected = (shape.bird_shape_id == selectedShapeId)
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
        cell.configure(shape: shape)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        IdentificationTooltipManager.shared.cancelTooltip()
        let shape = availableShapes[indexPath.item]
        selectedShapeId = shape.bird_shape_id
        collectionView.reloadData()
    }
}
