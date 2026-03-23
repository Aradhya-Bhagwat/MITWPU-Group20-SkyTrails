
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
	var watchlistType: WatchlistType = .custom
    var watchlistIdToEdit: UUID?
    private var watchlistToEdit: Watchlist?
	private var locationSuggestions: [LocationService.LocationSuggestion] = []
	private var selectedLocation: LocationService.LocationData?
	private var participants: [Participant] = []
	private var rulesContainerView: UIView!
	private var speciesRuleToggle: UISwitch!
	private var speciesRuleLabel: UILabel!
	private var shapeCollectionView: UICollectionView!
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
        DispatchQueue.main.async {
            self.setupRulesUI()
            self.populateRuleDataForEdit()
        }
	}
    
    @IBAction private func dateInputToggled() {
        UIView.animate(withDuration: 0.3) {
            self.dateCardView.isHidden = false
            self.dateCardView.alpha = 1.0
        }
    }
    
    @IBAction private func locationInputToggled() {
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
		self.title = (watchlistToEdit == nil) ? "Create Watchlist" : "Watchlist Settings"
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
    
    private func setupRulesUI() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        guard let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
            return
        }
        let mainStackView: UIStackView
        if let stackView = scrollView.subviews.compactMap({ $0 as? UIStackView }).first {
            mainStackView = stackView
        } else if let stackView = scrollView.subviews.flatMap({ $0.subviews }).compactMap({ $0 as? UIStackView }).first {
            mainStackView = stackView
        } else {
            return
        }

        let headerStack = UIStackView()
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = "Species"
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textColor = .label
        headerStack.addArrangedSubview(titleLabel)

        let infoButton = UIButton(type: .system)
        infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        infoButton.tintColor = .systemBlue
        infoButton.addTarget(self, action: #selector(didTapSpeciesInfo), for: .touchUpInside)
        headerStack.addArrangedSubview(infoButton)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(spacer)

        speciesRuleToggle = UISwitch()
        speciesRuleToggle.addTarget(self, action: #selector(speciesRuleToggled), for: .valueChanged)
        headerStack.addArrangedSubview(speciesRuleToggle)

        rulesContainerView = UIView()
        rulesContainerView.translatesAutoresizingMaskIntoConstraints = false
        rulesContainerView.backgroundColor = isDarkMode ? .secondarySystemBackground : .white
        rulesContainerView.layer.cornerRadius = 20
        rulesContainerView.layer.shadowColor = UIColor.black.cgColor
        rulesContainerView.layer.shadowOpacity = isDarkMode ? 0 : 0.08
        rulesContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        rulesContainerView.layer.shadowRadius = 12
        rulesContainerView.layer.masksToBounds = false

        let rulesStack = UIStackView()
        rulesStack.translatesAutoresizingMaskIntoConstraints = false
        rulesStack.axis = .vertical
        rulesStack.spacing = 20
        rulesStack.alignment = .fill
        rulesContainerView.addSubview(rulesStack)

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
        shapeCollectionView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        rulesStack.addArrangedSubview(shapeCollectionView)
        
        NSLayoutConstraint.activate([
            rulesStack.topAnchor.constraint(equalTo: rulesContainerView.topAnchor, constant: 16),
            rulesStack.leadingAnchor.constraint(equalTo: rulesContainerView.leadingAnchor, constant: 16),
            rulesStack.trailingAnchor.constraint(equalTo: rulesContainerView.trailingAnchor, constant: -16),
            rulesStack.bottomAnchor.constraint(equalTo: rulesContainerView.bottomAnchor, constant: -16)
        ])

        if let locationSectionIndex = mainStackView.arrangedSubviews.firstIndex(where: { view -> Bool in
            if view is UISearchBar {
                return true
            }
            if view == self.locationOptionsContainer {
                return true
            }
            return false
        }) {
            // Find the last view related to Location (the container)
            var insertIndex = locationSectionIndex
            for i in locationSectionIndex..<mainStackView.arrangedSubviews.count {
                if mainStackView.arrangedSubviews[i] == self.locationOptionsContainer {
                    insertIndex = i
                    break
                }
            }
            mainStackView.insertArrangedSubview(headerStack, at: insertIndex + 1)
            mainStackView.insertArrangedSubview(rulesContainerView, at: insertIndex + 2)
        } else {
            mainStackView.addArrangedSubview(headerStack)
            mainStackView.addArrangedSubview(rulesContainerView)
        }
        
        if watchlistIdToEdit != nil {
            let clearButton = UIButton(type: .system)
            clearButton.translatesAutoresizingMaskIntoConstraints = false
            clearButton.setTitle("Clear Watchlist", for: .normal)
            clearButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            clearButton.setTitleColor(.systemRed, for: .normal)
            clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            clearButton.layer.cornerRadius = 12
            clearButton.addTarget(self, action: #selector(didTapClearWatchlist), for: .touchUpInside)
            clearButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            mainStackView.addArrangedSubview(clearButton)

			let deleteButton = UIButton(type: .system)
			deleteButton.translatesAutoresizingMaskIntoConstraints = false
			deleteButton.setTitle("Delete Watchlist", for: .normal)
			deleteButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
			deleteButton.setTitleColor(.systemRed, for: .normal)
			deleteButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
			deleteButton.layer.cornerRadius = 12
			deleteButton.addTarget(self, action: #selector(didTapDeleteWatchlist), for: .touchUpInside)
			deleteButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

			mainStackView.addArrangedSubview(deleteButton)
        }
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
        let speciesShape = selectedShapeId ?? existingSpeciesShapeId
        let speciesParams: RuleParameters? = speciesShape.map {
            .speciesFamily(SpeciesFamilyRuleParams(shapeId: $0))
        }
        try manager.upsertRule(
            watchlistId: watchlistId,
            type: .species_family,
            parameters: speciesParams,
            isActive: speciesRuleToggle.isOn
        )
        
        let locationParams: RuleParameters?
        if let selectedLoc = selectedLocation {
            locationParams = .location(
                LocationRuleParams(
                    lat: selectedLoc.lat,
                    lon: selectedLoc.lon,
                    radiusKm: selectedRuleRadius
                )
            )
        } else if let existingLocationRuleData {
            locationParams = .location(
                LocationRuleParams(
                    lat: existingLocationRuleData.lat,
                    lon: existingLocationRuleData.lon,
                    radiusKm: existingLocationRuleData.radiusKm
                )
            )
        } else {
            locationParams = nil
        }
        try manager.upsertRule(
            watchlistId: watchlistId,
            type: .location,
            parameters: locationParams,
            isActive: locationInputToggle.isOn
        )
        
        let dateParams: RuleParameters? = .dateRange(
            DateRangeRuleParams(startDate: startDatePicker.date, endDate: endDatePicker.date)
        )
        try manager.upsertRule(
            watchlistId: watchlistId,
            type: .date_range,
            parameters: dateParams,
            isActive: dateInputToggle.isOn
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ShapeCell", for: indexPath)
        let shape = availableShapes[indexPath.item]
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
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
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: shape.icon)
        cell.contentView.addSubview(imageView)
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
        selectedShapeId = shape.bird_shape_id
        collectionView.reloadData()
    }
}
