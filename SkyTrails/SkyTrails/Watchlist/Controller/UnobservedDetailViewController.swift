import UIKit
import MapKit
import CoreLocation

@MainActor
class UnobservedDetailViewController: UIViewController {

	private let manager = WatchlistManager.shared
	private let locationService = LocationService.shared
	
		// MARK: - Dependencies
	var bird: Bird?
    var entry: WatchlistEntry? // Added
	var watchlistId: UUID?
	var onSave: ((Bird) -> Void)?
	
		// MARK: - Private Properties
	private var locationSuggestions: [LocationService.LocationSuggestion] = []
	private var selectedLocation: LocationService.LocationData?
	
		// MARK: - IBOutlets
	@IBOutlet weak var suggestionsTableView: UITableView!
	@IBOutlet weak var birdImageView: UIImageView!
	@IBOutlet weak var startLabel: UILabel!
	@IBOutlet weak var endLabel: UILabel!
	@IBOutlet weak var startDatePicker: UIDatePicker!
	@IBOutlet weak var endDatePicker: UIDatePicker!
	@IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var notesCardView: UIView!
	@IBOutlet weak var locationSearchBar: UISearchBar!
	@IBOutlet weak var detailsCardView: UIView!
	@IBOutlet weak var locationCardView: UIView!
	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupLocationServices()
		setupSearch()
		setupKeyboardHandling()
		configureView()
	}
	
		// MARK: - Setup
	private func setupUI() {
		title = bird?.name ?? "Add Species"
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
		view.backgroundColor = isDarkMode ? .systemBackground : .systemGray6
        suggestionsTableView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
		
		birdImageView.layer.cornerRadius = 24
		birdImageView.clipsToBounds = true
        notesTextView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        notesTextView.textColor = .label
        notesTextView.layer.cornerRadius = 12
        notesTextView.layer.masksToBounds = true
        notesTextView.layer.borderWidth = 0
        notesTextView.layer.borderColor = UIColor.clear.cgColor
        styleSearchBar(locationSearchBar, isDarkMode: isDarkMode)
		
		styleCard(detailsCardView)
        styleCard(notesCardView)
		styleCard(locationCardView)
		
		setupLocationOptionsInteractions()
		setupNavigationItems()
	}
	
	private func styleCard(_ view: UIView) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
		view.layer.cornerRadius = 20
		view.backgroundColor = isDarkMode ? .secondarySystemBackground : .white
		view.layer.shadowColor = UIColor.black.cgColor
		view.layer.shadowOpacity = isDarkMode ? 0 : 0.08
		view.layer.shadowOffset = CGSize(width: 0, height: 4)
		view.layer.shadowRadius = 12
		view.layer.masksToBounds = false
	}

    private func styleSearchBar(_ searchBar: UISearchBar, isDarkMode: Bool) {
        let textField = searchBar.searchTextField
        textField.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        textField.textColor = .label
        textField.layer.cornerRadius = 12
        textField.layer.masksToBounds = true
        textField.leftView?.tintColor = .secondaryLabel
    }
	
	private func setupNavigationItems() {
		if bird != nil {
			let deleteButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(didTapDelete))
			deleteButton.tintColor = .systemRed
			
			let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
			navigationItem.rightBarButtonItems = [saveButton, deleteButton]
		} else {
			let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
			navigationItem.rightBarButtonItem = saveButton
		}
	}
	
	private func setupLocationServices() {
	}
	
	private func setupSearch() {
		locationSearchBar.delegate = self
		suggestionsTableView.delegate = self
		suggestionsTableView.dataSource = self
		suggestionsTableView.isHidden = true
	}
	
	private func setupKeyboardHandling() {
		let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
		tap.cancelsTouchesInView = false
		view.addGestureRecognizer(tap)
	}
	
	private func setupLocationOptionsInteractions() {
		guard let container = locationCardView,
			  let mainStack = container.subviews.first as? UIStackView,
			  mainStack.arrangedSubviews.count >= 3 else { return }
		
		let currentLocationView = mainStack.arrangedSubviews[0]
		let mapView = mainStack.arrangedSubviews[2]
		
		addTapGesture(to: currentLocationView, action: #selector(didTapCurrentLocation))
		addTapGesture(to: mapView, action: #selector(didTapMap))
	}
	
	private func addTapGesture(to view: UIView, action: Selector) {
		let tap = UITapGestureRecognizer(target: self, action: action)
		view.isUserInteractionEnabled = true
		view.addGestureRecognizer(tap)
	}
	
	private func configureView() {
		guard let bird = bird else { return }
		
		navigationItem.title = "Edit Species"
		loadImage(for: bird)
		
        if let entry = entry {
            if let date = entry.toObserveStartDate { startDatePicker.date = date }
            if let date = entry.toObserveEndDate { endDatePicker.date = date }
            notesTextView.text = entry.notes ?? ""
        } else {
             notesTextView.text = ""
        }
		
		if let displayName = entry?.locationDisplayName {
			updateLocationSelection(displayName, lat: entry?.lat, lon: entry?.lon)
		} else if let lat = entry?.lat, let lon = entry?.lon {
			Task { [weak self] in
				guard let self else { return }
				let name = await self.locationService.reverseGeocode(lat: lat, lon: lon) ?? "Location"
				await MainActor.run { self.updateLocationSelection(name, lat: lat, lon: lon) }
			}
		} else {
			updateLocationSelection(bird.validLocations?.first ?? "")
		}
	}
	
	private func loadImage(for bird: Bird) {
		let imageName = bird.staticImageName
		if let assetImage = UIImage(named: imageName) {
			birdImageView.image = assetImage
		} else {
			let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(imageName)
			if let docImage = UIImage(contentsOfFile: fileURL.path) {
				birdImageView.image = docImage
			} else {
				birdImageView.image = UIImage(systemName: "photo")
			}
		}
	}
	
		// MARK: - Actions
	@objc private func dismissKeyboard() {
		view.endEditing(true)
		suggestionsTableView.isHidden = true
	}
	
	@objc private func didTapCurrentLocation() {
		Task {
			do {
				let location = try await locationService.getCurrentLocation()
				updateLocationSelection(location)
			} catch {
				let alert = UIAlertController(title: "Location Unavailable", message: "Please enable location services in Settings.", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .default))
				present(alert, animated: true)
			}
		}
	}
	
	@objc private func didTapMap() {
		let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
		if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
			mapVC.delegate = self
			navigationController?.pushViewController(mapVC, animated: true)
		}
	}
	
	@objc private func didTapDelete() {
        if let entryId = entry?.id {
            let alert = UIAlertController(title: "Delete Bird", message: "Delete this bird from watchlist?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
                self?.manager.deleteEntry(entryId: entryId)
                self?.navigationController?.popViewController(animated: true)
            }))
            present(alert, animated: true)
        } else {
             navigationController?.popViewController(animated: true)
        }
	}
	
	@objc private func didTapSave() {
        print("💾 [UnobservedDetailVC] didTapSave() called")
        
        // Logic handling
        let notes = notesTextView.text
        let startDate = startDatePicker.date
        let endDate = endDatePicker.date
        
        print("📝 [UnobservedDetailVC] Notes: \(notes ?? "nil")")
        print("📅 [UnobservedDetailVC] Start date: \(startDate)")
        print("📅 [UnobservedDetailVC] End date: \(endDate)")
        
        		if let existingEntry = entry {
        
        			print("✏️  [UnobservedDetailVC] Editing existing entry: \(existingEntry.id)")
        
        			
        
        			// Update dates FIRST so they are included when updateEntry triggers a save
        
        			existingEntry.toObserveStartDate = startDate
        
        			existingEntry.toObserveEndDate = endDate
        
        			
                    do {
                        try manager.updateEntry(entryId: existingEntry.id, notes: notes, observationDate: nil, lat: selectedLocation?.lat, lon: selectedLocation?.lon, locationDisplayName: selectedLocation?.displayName)
                        
                        print("✅ [UnobservedDetailVC] Updated existing entry, popping view controller")
                        navigationController?.popViewController(animated: true)
                    } catch {
                        print("❌ [UnobservedDetailVC] Error updating entry: \(error)")
                    }
        
        			
        
        			
        
        		} else if let wId = watchlistId, let bird = bird {
        
        			print("➕ [UnobservedDetailVC] Creating new entry")
        
        			print("🐦 [UnobservedDetailVC] Bird: \(bird.commonName)")
        
        			print("📋 [UnobservedDetailVC] Watchlist ID: \(wId)")
        
        			
                    do {
                        try manager.addBirds([bird], to: wId, asObserved: false)
                        
                        if let newEntry = try? manager.findEntry(birdId: bird.id, watchlistId: wId) {
            
                            print("✅ [UnobservedDetailVC] Found new entry: \(newEntry.id)")
                            
                            // Set dates (in memory)
                            newEntry.toObserveStartDate = startDate
                            newEntry.toObserveEndDate = endDate
                            
                            // Call updateEntry to set notes and SAVE everything
                            try manager.updateEntry(entryId: newEntry.id, notes: notes, observationDate: nil, lat: selectedLocation?.lat, lon: selectedLocation?.lon, locationDisplayName: selectedLocation?.displayName)
                            
                            print("✅ [UnobservedDetailVC] Entry properties updated and saved")
                        } else {
                            print("❌ [UnobservedDetailVC] ERROR: Could not find newly created entry!")
                        }
                    } catch {
                        print("❌ [UnobservedDetailVC] ERROR creating entry: \(error)")
                    }
        
        			
        
        			print("📞 [UnobservedDetailVC] Calling onSave callback")
        
        			onSave?(bird)
        
        			
        
        			print("✅ [UnobservedDetailVC] Complete, popping view controller")
        
        			navigationController?.popViewController(animated: true)
        
        		} else {
            print("⚠️  [UnobservedDetailVC] No entry or bird/watchlistId - just popping")
            navigationController?.popViewController(animated: true)
        }
	}
	
	private func updateLocationSelection(_ location: LocationService.LocationData) {
		locationSearchBar.text = location.displayName
		selectedLocation = location
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
	}
	
	private func updateLocationSelection(_ name: String, lat: Double? = nil, lon: Double? = nil) {
		locationSearchBar.text = name
		if let lat = lat, let lon = lon {
			selectedLocation = LocationService.LocationData(displayName: name, lat: lat, lon: lon)
		} else {
			selectedLocation = nil
		}
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
	}
}

	// MARK: - CLLocationManagerDelegate
extension UnobservedDetailViewController: CLLocationManagerDelegate {
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

	// MARK: - UITableViewDelegate & DataSource
extension UnobservedDetailViewController: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return locationSuggestions.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
		let result = locationSuggestions[indexPath.row]
		cell.textLabel?.text = result.fullText
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        cell.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        cell.textLabel?.textColor = .label
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
				await MainActor.run { self.updateLocationSelection(query, lat: nil, lon: nil) }
			}
		}
	}
}

	// MARK: - UISearchBarDelegate
extension UnobservedDetailViewController: UISearchBarDelegate {
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
		if !locationSuggestions.isEmpty {
			suggestionsTableView.isHidden = false
		}
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchBar.resignFirstResponder()
		suggestionsTableView.isHidden = true
	}
}

	// MARK: - MKLocalSearchCompleterDelegate
extension UnobservedDetailViewController: MKLocalSearchCompleterDelegate {
	func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {}
}

extension UnobservedDetailViewController: MapSelectionDelegate {
	func didSelectMapLocation(name: String, lat: Double, lon: Double) {
		updateLocationSelection(name, lat: lat, lon: lon)
	}
}
