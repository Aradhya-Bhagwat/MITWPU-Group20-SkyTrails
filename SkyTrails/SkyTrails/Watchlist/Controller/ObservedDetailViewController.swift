import UIKit
import MapKit
import CoreLocation
import SwiftData

@MainActor
class ObservedDetailViewController: UIViewController {
	
	private let manager = WatchlistManager.shared
	private let locationService = LocationService.shared
	
		// MARK: - Data Dependency
	var bird: Bird? // Kept for 'New Observation' flow where entry doesn't exist yet
	var entry: WatchlistEntry? // The existing entry being edited
	var watchlistId: UUID?
	
	var onSave: ((Bird) -> Void)?
	
	private var selectedImageName: String?
	private var selectedLocation: LocationService.LocationData?
	
		// Location Autocomplete State
	private var locationSuggestions: [LocationService.LocationSuggestion] = []
	
	@IBOutlet weak var suggestionsTableView: UITableView!
	@IBOutlet weak var birdImageView: UIImageView!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var dateTimePicker: UIDatePicker!
	@IBOutlet weak var notesTextView: UITextView!
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var locationSearchBar: UISearchBar!
	@IBOutlet weak var detailsCardView: UIView!
	@IBOutlet weak var notesCardView: UIView!
	@IBOutlet weak var locationCardView: UIView!
	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		print("Debug: viewDidLoad started")
		
		if let entry = entry {
			self.title = entry.bird?.commonName
			self.bird = entry.bird
			print("Debug: viewDidLoad - loaded existing entry for bird: \(entry.bird?.commonName ?? "nil")")
		} else {
			self.title = bird?.commonName
			print("Debug: viewDidLoad - no existing entry, bird: \(bird?.commonName ?? "nil")")
		}
		
		setupStyling()
		setupSearch()
		setupInteractions()
		
		dateTimePicker.maximumDate = Date()
		
		if let entry = entry {
			configure(with: entry)
			setupRightBarButtons()
		} else if let birdData = bird {
				// New observation for specific bird
			nameTextField.text = birdData.commonName
			birdImageView.image = UIImage(named: birdData.staticImageName) ?? UIImage(systemName: "photo")
			setupRightBarButtons() // Can delete only if entry exists? No, cancel.
			print("Debug: viewDidLoad - configured for new observation with bird: \(birdData.commonName)")
		} else {
				// Completely new
			self.navigationItem.title = "New Observation"
			birdImageView.image = UIImage(systemName: "camera.fill")
			birdImageView.tintColor = .systemGray
			let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
			navigationItem.rightBarButtonItem = saveButton
			print("Debug: viewDidLoad - configured for completely new observation")
		}
		
		setupKeyboardHandling()
		setupLocationServices()
		setupLocationOptionsInteractions()
		print("Debug: viewDidLoad completed")
	}
	
	private func setupLocationServices() {
		print("Debug: setupLocationServices called")
	}
	
	private func setupSearch() {
		print("Debug: setupSearch called")
		locationSearchBar.delegate = self
		suggestionsTableView.delegate = self
		suggestionsTableView.dataSource = self
		suggestionsTableView.isHidden = true
	}
	
	private func setupLocationOptionsInteractions() {
		print("Debug: setupLocationOptionsInteractions called")
		guard let container = locationCardView,
			  let mainStack = container.subviews.first as? UIStackView,
			  mainStack.arrangedSubviews.count >= 3 else {
			print("Debug: setupLocationOptionsInteractions - failed to get views")
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
		print("Debug: setupLocationOptionsInteractions - gesture recognizers added")
	}
	
	@objc private func didTapCurrentLocation() {
		print("Debug: didTapCurrentLocation called")
		Task {
			do {
				let location = try await locationService.getCurrentLocation()
				updateLocationSelection(location)
			} catch {
				print("Debug: didTapCurrentLocation - error: \(error)")
				let alert = UIAlertController(title: "Location Unavailable", message: "Please enable location services in Settings.", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .default))
				present(alert, animated: true)
			}
		}
	}
	
	@objc private func didTapMap() {
		print("Debug: didTapMap called")
		let storyboard = UIStoryboard(name:"SharedStoryboard", bundle:nil)
		if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
			mapVC.delegate = self
			navigationController?.pushViewController(mapVC, animated: true)
			print("Debug: didTapMap - navigated to MapViewController")
		} else {
			print("Debug: didTapMap - failed to instantiate MapViewController")
		}
	}
	
	private func updateLocationSelection(_ location: LocationService.LocationData) {
		print("Debug: updateLocationSelection called with location: \(location)")
		locationSearchBar.text = location.displayName
		selectedLocation = location
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
	}
	
	private func updateLocationSelection(_ name: String, lat: Double? = nil, lon: Double? = nil) {
		print("Debug: updateLocationSelection called with name: '\(name)', lat: \(lat?.description ?? "nil"), lon: \(lon?.description ?? "nil")")
		locationSearchBar.text = name
		if let lat = lat, let lon = lon {
			selectedLocation = LocationService.LocationData(displayName: name, lat: lat, lon: lon)
		} else {
			selectedLocation = nil
		}
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
	}
	
		// MARK: - Keyboard Handling
	private func setupKeyboardHandling() {
		let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
		tap.cancelsTouchesInView = false
		tap.delegate = self
		view.addGestureRecognizer(tap)
		addDoneButtonOnKeyboard()
	}
	
	@objc func dismissKeyboard() {
		print("Debug: dismissKeyboard called")
		view.endEditing(true)
		suggestionsTableView.isHidden = true
	}
	
	private func addDoneButtonOnKeyboard() {
		let doneToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 50))
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let done = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(doneButtonAction))
		doneToolbar.items = [flexSpace, done]
		doneToolbar.sizeToFit()
		nameTextField.inputAccessoryView = doneToolbar
		notesTextView.inputAccessoryView = doneToolbar
	}
	
	@objc func doneButtonAction() {
		print("Debug: doneButtonAction called")
		view.endEditing(true)
	}
	
	private func setupRightBarButtons() {
		let deleteButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(didTapDelete))
		deleteButton.tintColor = .systemRed
		let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
		navigationItem.rightBarButtonItems = [saveButton, deleteButton]
	}
	
	@objc private func didTapDelete() {
		if let entry = entry {
			let alert = UIAlertController(title: "Delete Observation", message: "Are you sure?", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
			alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
                do {
                    try self?.manager.deleteEntry(entryId: entry.id)
                    self?.navigationController?.popViewController(animated: true)
                } catch {
                    print("❌ Error deleting entry: \(error)")
                }
			}))
			present(alert, animated: true)
		} else {
				// Just pop if it wasn't saved yet
			navigationController?.popViewController(animated: true)
		}
	}
	
	private func setupInteractions() {
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapImage))
		birdImageView.isUserInteractionEnabled = true
		birdImageView.addGestureRecognizer(tapGesture)
	}
	
	@objc func didTapImage() {
		let picker = UIImagePickerController()
		picker.sourceType = .photoLibrary
		picker.delegate = self
		picker.allowsEditing = true
		present(picker, animated: true)
	}
	
	@objc func didTapSave() {
		print("💾 [ObservedDetailVC] didTapSave() called")
		
		guard let name = nameTextField.text, !name.isEmpty else {
			print("❌ [ObservedDetailVC] ERROR: Name is empty, cannot save")
			return
		}
		
		print("📝 [ObservedDetailVC] Bird name: \(name)")
		print("📅 [ObservedDetailVC] Observation date: \(dateTimePicker.date)")
		print("📝 [ObservedDetailVC] Notes: \(notesTextView.text ?? "nil")")
		
		if let existingEntry = entry {
			print("✏️  [ObservedDetailVC] Editing existing entry: \(existingEntry.id)")
				// Update using manager
			do {
				try manager.updateEntry(
					entryId: existingEntry.id,
					notes: notesTextView.text,
					observationDate: dateTimePicker.date,
					lat: selectedLocation?.lat,
					lon: selectedLocation?.lon,
					locationDisplayName: selectedLocation?.displayName
				)
					// Persist newly picked photo if the user changed it
				if let photoName = selectedImageName {
					try manager.attachPhoto(entryId: existingEntry.id, imageName: photoName)
					print("📸 [ObservedDetailVC] Photo attached to existing entry: \(photoName)")
				}
				print("✅ [ObservedDetailVC] Updated existing entry")
				
				if let bird = existingEntry.bird {
					print("📞 [ObservedDetailVC] Calling onSave callback for existing bird")
					onSave?(bird)
				}
			} catch {
				print("❌ [ObservedDetailVC] ERROR updating entry: \(error)")
			}
		} else if let wId = watchlistId {
			print("➕ [ObservedDetailVC] Creating new entry")
			print("📋 [ObservedDetailVC] Watchlist ID: \(wId)")
			
				// New Entry
			let birdToUse: Bird
			if let existingBird = bird {
				print("🐦 [ObservedDetailVC] Using existing bird: \(existingBird.commonName)")
				birdToUse = existingBird
			} else if let found = manager.findBird(byName: name) {
				print("🔍 [ObservedDetailVC] Found existing bird in DB: \(found.commonName)")
				birdToUse = found
			} else {
				print("➕ [ObservedDetailVC] Creating new bird: \(name)")
				birdToUse = manager.createBird(name: name)
			}
			
			print("💾 [ObservedDetailVC] Adding bird to watchlist as observed")
			do {
				try manager.addBirds([birdToUse], to: wId, asObserved: true)
				
				if let newEntry = try? manager.findEntry(birdId: birdToUse.id, watchlistId: wId) {
						// Update the newly created entry with notes and the specific date picked by user
					try manager.updateEntry(
						entryId: newEntry.id,
						notes: notesTextView.text,
						observationDate: dateTimePicker.date,
						lat: selectedLocation?.lat,
						lon: selectedLocation?.lon,
						locationDisplayName: selectedLocation?.displayName
					)
					
						// Persist newly picked photo to the entry
					if let photoName = selectedImageName {
						try manager.attachPhoto(entryId: newEntry.id, imageName: photoName)
						print("📸 [ObservedDetailVC] Photo attached to new entry: \(photoName)")
					}
				}
				
				print("📞 [ObservedDetailVC] Calling onSave callback for new bird")
				onSave?(birdToUse)
			} catch {
				print("❌ [ObservedDetailVC] ERROR creating entry: \(error)")
			}
		} else {
			print("⚠️  [ObservedDetailVC] No watchlistId available")
		}
		
		print("✅ [ObservedDetailVC] Complete, popping view controller")
		navigationController?.popViewController(animated: true)
	}
		
		print("✅ [ObservedDetailVC] Complete, popping view controller")
		navigationController?.popViewController(animated: true)
	}
	
	func configure(with entry: WatchlistEntry) {
		print("Debug: configure(with:) called for entry: \(entry.id)")
		guard let bird = entry.bird else {
			print("Debug: configure(with:) - no bird found in entry")
			return
		}
		nameTextField.text = bird.commonName
		print("Debug: configure(with:) - bird name: \(bird.commonName)")
		
		if let displayName = entry.locationDisplayName {
			print("Debug: configure(with:) - using stored displayName: \(displayName)")
			let lat = entry.lat
			let lon = entry.lon
			updateLocationSelection(displayName, lat: lat, lon: lon)
		} else if let lat = entry.lat, let lon = entry.lon {
			print("Debug: configure(with:) - no displayName, but coordinates found. lat: \(lat), lon: \(lon)")
			Task { [weak self] in
				guard let self else { return }
				print("Debug: configure(with:) Task - starting reverse geocoding fallback")
				let name = await locationService.reverseGeocode(lat: lat, lon: lon) ?? "Location"
				await MainActor.run {
					self.updateLocationSelection(name, lat: lat, lon: lon)
				}
			}
		} else {
			let fallbackLocation = bird.validLocations?.first ?? ""
			print("Debug: configure(with:) - no coordinates or name, using fallback location: '\(fallbackLocation)'")
			updateLocationSelection(fallbackLocation)
		}
		
			// Three-tier image resolution: user photo on disk → asset catalogue → placeholder
		birdImageView.image = ObservedDetailViewController.loadImage(for: entry)
		
		if let date = entry.observationDate {
			dateTimePicker.date = date
			print("Debug: configure(with:) - set observation date: \(date)")
		}
		notesTextView.text = entry.notes
		print("Debug: configure(with:) - set notes: '\(entry.notes ?? "nil")'")
	}
	
		/// Resolves the best available image for an entry.
		/// Priority: user-captured photo on disk → bundled asset → system placeholder.
	private static func loadImage(for entry: WatchlistEntry) -> UIImage {
		if let photoPath = entry.photos?.first?.imagePath {
			let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
			let fileURL = supportDir.appendingPathComponent(photoPath)
			if let image = UIImage(contentsOfFile: fileURL.path) {
				return image
			}
		}
		if let bird = entry.bird, let asset = UIImage(named: bird.staticImageName) {
			return asset
		}
		return UIImage(systemName: "photo")!
	}
	
	func setupStyling() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
		view.backgroundColor = isDarkMode ? .systemBackground : .systemGray6
        suggestionsTableView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
		birdImageView.layer.cornerRadius = 24
		birdImageView.clipsToBounds = true
        nameTextField.backgroundColor = isDarkMode ? .secondarySystemBackground : .white
        nameTextField.textColor = .label
        nameTextField.layer.cornerRadius = 12
        nameTextField.layer.masksToBounds = true
        notesTextView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        notesTextView.textColor = .label
        notesTextView.layer.cornerRadius = 12
        notesTextView.layer.masksToBounds = true
        styleSearchBar(locationSearchBar, isDarkMode: isDarkMode)
		[detailsCardView, notesCardView, locationCardView].forEach { styleCard($0) }
	}
	
	func styleCard(_ cardView: UIView) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
		cardView.layer.cornerRadius = 20
		cardView.backgroundColor = isDarkMode ? .secondarySystemBackground : .white
        cardView.layer.shadowColor = UIColor.black.cgColor
		cardView.layer.shadowOpacity = isDarkMode ? 0 : 0.08
		cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
		cardView.layer.shadowRadius = 12
        cardView.layer.masksToBounds = false
	}

    private func styleSearchBar(_ searchBar: UISearchBar, isDarkMode: Bool) {
        let textField = searchBar.searchTextField
        textField.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        textField.textColor = .label
        textField.layer.cornerRadius = 12
        textField.layer.masksToBounds = true
        textField.leftView?.tintColor = .secondaryLabel
    }
}

	// MARK: - Protocols & Delegates
extension ObservedDetailViewController: UISearchBarDelegate, MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {
	
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		print("Debug: searchBar textDidChange - new text: '\(searchText)'")
		selectedLocation = nil
		if searchText.isEmpty {
			print("Debug: searchBar textDidChange - text is empty, hiding suggestions")
			locationSuggestions = []
			suggestionsTableView.isHidden = true
		} else {
			print("Debug: searchBar textDidChange - fetching suggestions from LocationService")
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
		print("Debug: searchBarTextDidBeginEditing - locationSuggestions.count: \(locationSuggestions.count)")
		if !locationSuggestions.isEmpty {
			suggestionsTableView.isHidden = false
			print("Debug: searchBarTextDidBeginEditing - showing suggestions table")
		}
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		print("Debug: searchBarSearchButtonClicked - text: '\(searchBar.text ?? "nil")'")
		searchBar.resignFirstResponder()
		suggestionsTableView.isHidden = true
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		print("Debug: tableView numberOfRowsInSection - returning: \(locationSuggestions.count)")
		return locationSuggestions.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
		let item = locationSuggestions[indexPath.row]
		cell.textLabel?.text = item.fullText
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        cell.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        cell.textLabel?.textColor = .label
		print("Debug: tableView cellForRowAt - row \(indexPath.row): '\(item.fullText)'")
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = locationSuggestions[indexPath.row]
		let fullLocationText = item.fullText
		print("Debug: tableView didSelectRowAt - row \(indexPath.row) selected: '\(fullLocationText)'")
		
			// Immediately update UI and hide table
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
		
		Task {
			print("Debug: tableView didSelectRowAt Task - geocoding selected suggestion")
			do {
				let location = try await locationService.geocode(query: fullLocationText)
                
                // Use the text the user actually clicked on, rather than the geocoded name
                let finalLocation = LocationService.LocationData(
                    displayName: fullLocationText,
                    lat: location.lat,
                    lon: location.lon
                )
                
				await MainActor.run {
					self.updateLocationSelection(finalLocation)
				}
			} catch {
				print("Debug: tableView didSelectRowAt Task - geocoding FAILED")
				await MainActor.run {
					// Fallback: use text but nil coordinates
					self.updateLocationSelection(fullLocationText, lat: nil, lon: nil)
				}
			}
		}
	}
	
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
	}
	
		// MARK: - UIGestureRecognizerDelegate
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
			// Don't trigger dismissKeyboard when tapping on the suggestions tableview
		if touch.view?.isDescendant(of: suggestionsTableView) == true {
			print("Debug: gestureRecognizer shouldReceive - touch is on suggestionsTableView, ignoring")
			return false
		}
		print("Debug: gestureRecognizer shouldReceive - touch is NOT on suggestionsTableView, allowing")
		return true
	}
}

extension ObservedDetailViewController: MapSelectionDelegate {
	func didSelectMapLocation(name: String, lat: Double, lon: Double) {
		print("Debug: didSelectMapLocation called - name: '\(name)', lat: \(lat), lon: \(lon)")
		updateLocationSelection(name, lat: lat, lon: lon)
	}
}

extension ObservedDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		picker.dismiss(animated: true)
		guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else { return }
		
		birdImageView.image = image
		
			// Persist to applicationSupportDirectory so it survives app launches
		let filename = "bird_photo_\(UUID().uuidString).png"
		if let data = image.pngData() {
			let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
			let fileURL = supportDir.appendingPathComponent(filename)
			do {
				try data.write(to: fileURL)
				selectedImageName = filename
				print("📸 [ObservedDetailVC] Photo saved to disk: \(filename)")
			} catch {
				print("❌ [ObservedDetailVC] Failed to write photo: \(error)")
			}
		}
	}
}
