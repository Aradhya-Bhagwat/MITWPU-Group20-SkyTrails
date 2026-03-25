import UIKit
import MapKit
import CoreLocation

@MainActor
class UnobservedDetailViewController: UIViewController {

	private let manager = WatchlistManager.shared
	private let locationService = LocationService.shared
    private var imageLoadTask: Task<Void, Never>?
	var bird: Bird?
    var entry: WatchlistEntry?
	var watchlistId: UUID?
	var shouldUseRuleMatching: Bool = false
	var onSave: ((Bird) -> Void)?
	private var locationSuggestions: [LocationService.LocationSuggestion] = []
	private var selectedLocation: LocationService.LocationData?
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
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupLocationServices()
		setupSearch()
		setupKeyboardHandling()
		configureView()
	}
	private func setupUI() {
		title = bird?.name ?? "Plan Sighting"
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
		
		navigationItem.title = "\(bird.name) Details"
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
			updateLocationSelection(bird.likelySpot ?? "")
		}
	}
	
	private func loadImage(for bird: Bird) {
		let imageName = bird.staticImageName
        imageLoadTask?.cancel()
        birdImageView.image = WatchlistImageLoader.previewImage(named: imageName) ?? UIImage(systemName: "photo")

        imageLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let image = await WatchlistImageLoader.image(named: imageName)
            guard !Task.isCancelled else { return }

            self.birdImageView.image = image ?? UIImage(systemName: "photo")
        }
	}
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
                try? self?.manager.deleteEntry(entryId: entryId)
                self?.navigationController?.popViewController(animated: true)
            }))
            present(alert, animated: true)
        } else {
             navigationController?.popViewController(animated: true)
        }
	}
	
	@objc private func didTapSave() {
        Task {
            let params = WatchlistEntryOrchestrationService.SaveParameters(
                entry: entry,
                bird: bird,
                birdName: bird?.name,
                watchlistId: watchlistId,
                notes: notesTextView.text,
                location: selectedLocation,
                observationDate: startDatePicker.date,
                endDate: endDatePicker.date,
                photoName: nil,
                asObserved: false,
                shouldUseRuleMatching: shouldUseRuleMatching
            )
            
            let result = await manager.orchestrationService.saveEntry(params: params)
            
            if result.noMatchingWatchlists {
                let alert = UIAlertController(
                    title: "No Matching Watchlists",
                    message: "Bird could not find any matching watchlists",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
            
            if result.success, let callbackBird = result.bird {
                if let onSave = onSave {
                    onSave(callbackBird)
                } else {
                    navigationController?.popViewController(animated: true)
                }
            } else {
                navigationController?.popViewController(animated: true)
            }
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
extension UnobservedDetailViewController: CLLocationManagerDelegate {
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
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
extension UnobservedDetailViewController: MKLocalSearchCompleterDelegate {
	func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {}
}

extension UnobservedDetailViewController: MapSelectionDelegate {
	func didSelectMapLocation(name: String, lat: Double, lon: Double) {
		updateLocationSelection(name, lat: lat, lon: lon)
	}
}
