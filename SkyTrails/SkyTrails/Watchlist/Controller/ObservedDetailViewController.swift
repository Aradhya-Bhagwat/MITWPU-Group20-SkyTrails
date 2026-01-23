import UIKit
import MapKit
import CoreLocation

class ObservedDetailViewController: UIViewController {
	
		// MARK: - Data Dependency
	var bird: Bird?
	var watchlistId: UUID?
	var onSave: ((Bird) -> Void)?
	
	private let locationManager = CLLocationManager()
	private var selectedImageName: String?
	
		// Location Autocomplete State
	private var searchCompleter = MKLocalSearchCompleter()
	private var locationResults: [MKLocalSearchCompletion] = []
	
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
		self.title = bird?.name
		setupStyling()
		setupSearch()
		setupInteractions()
		
		dateTimePicker.maximumDate = Date()
		
		if let birdData = bird {
			configure(with: birdData)
			setupRightBarButtons()
		} else {
			self.navigationItem.title = "New Observation"
			birdImageView.image = UIImage(systemName: "camera.fill")
			birdImageView.tintColor = .systemGray
			let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
			navigationItem.rightBarButtonItem = saveButton
		}
		
		setupKeyboardHandling()
		setupLocationServices()
		setupLocationOptionsInteractions()
	}
	
	private func setupLocationServices() {
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
	}
	
	private func setupSearch() {
		searchCompleter.delegate = self
		locationSearchBar.delegate = self
		suggestionsTableView.delegate = self
		suggestionsTableView.dataSource = self
		suggestionsTableView.isHidden = true
	}
	
	private func setupLocationOptionsInteractions() {
		guard let container = locationCardView,
			  let mainStack = container.subviews.first as? UIStackView,
			  mainStack.arrangedSubviews.count >= 3 else { return }
		
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
		let authStatus = locationManager.authorizationStatus
		switch authStatus {
			case .notDetermined:
				locationManager.requestWhenInUseAuthorization()
			case .restricted, .denied:
				let alert = UIAlertController(title: "Location Access Denied", message: "Please enable location services in Settings.", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .default))
				present(alert, animated: true)
			case .authorizedAlways, .authorizedWhenInUse:
				locationManager.requestLocation()
			@unknown default:
				break
		}
	}
	
	@objc private func didTapMap() {
		let storyboard = UIStoryboard(name:"SharedStoryboard", bundle:nil)
		if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
			mapVC.delegate = self
			navigationController?.pushViewController(mapVC, animated: true)
		}
	}
	
	private func updateLocationSelection(_ name: String) {
		locationSearchBar.text = name
		suggestionsTableView.isHidden = true
		locationSearchBar.resignFirstResponder()
	}
	
		// MARK: - Keyboard Handling
	private func setupKeyboardHandling() {
		let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
		tap.cancelsTouchesInView = false
		view.addGestureRecognizer(tap)
		addDoneButtonOnKeyboard()
	}
	
	@objc func dismissKeyboard() {
		view.endEditing(true)
		suggestionsTableView.isHidden = true
	}
	
	private func addDoneButtonOnKeyboard() {
		let doneToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 50))
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonAction))
		doneToolbar.items = [flexSpace, done]
		doneToolbar.sizeToFit()
		nameTextField.inputAccessoryView = doneToolbar
		notesTextView.inputAccessoryView = doneToolbar
	}
	
	@objc func doneButtonAction() {
		view.endEditing(true)
	}
	
	private func setupRightBarButtons() {
		let deleteButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(didTapDelete))
		deleteButton.tintColor = .systemRed
		let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
		navigationItem.rightBarButtonItems = [saveButton, deleteButton]
	}
	
	@objc private func didTapDelete() {
		guard let birdToDelete = bird, let id = watchlistId else { return }
		let alert = UIAlertController(title: "Delete Observation", message: "Are you sure?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
			WatchlistManager.shared.deleteBird(birdToDelete, from: id)
			self?.navigationController?.popViewController(animated: true)
		}))
		present(alert, animated: true)
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
		guard let name = nameTextField.text, !name.isEmpty else { return }
		
		var images: [String] = []
		if let imgName = selectedImageName { images.append(imgName) }
		else if let existing = bird?.images.first { images.append(existing) }
		else { images.append("bird_placeholder") }
		
		let newBird = Bird(
			id: bird?.id ?? UUID(),
			name: name,
			scientificName: "Unknown",
			images: images,
			rarity: [.common],
			location: [locationSearchBar.text ?? "Unknown Location"],
			date: [dateTimePicker.date],
			observedBy: ["person.circle.fill"],
			notes: notesTextView.text
		)
		
		if let wId = watchlistId {
			WatchlistManager.shared.saveObservation(bird: newBird, watchlistId: wId)
			navigationController?.popViewController(animated: true)
		} else {
			onSave?(newBird)
		}
	}
	
	func configure(with bird: Bird) {
		nameTextField.text = bird.name
		locationSearchBar.text = bird.location.first
		if let imageName = bird.images.first {
			birdImageView.image = UIImage(named: imageName) ?? UIImage(systemName: "photo")
		}
		if let date = bird.date.first { dateTimePicker.date = date }
		notesTextView.text = bird.notes
	}
	
	func setupStyling() {
		view.backgroundColor = .systemGray6
		birdImageView.layer.cornerRadius = 24
		birdImageView.clipsToBounds = true
		[detailsCardView, notesCardView, locationCardView].forEach { styleCard($0) }
	}
	
	func styleCard(_ view: UIView) {
		view.layer.cornerRadius = 20
		view.backgroundColor = .white
		view.layer.shadowOpacity = 0.08
		view.layer.shadowOffset = CGSize(width: 0, height: 4)
		view.layer.shadowRadius = 12
	}
}

	// MARK: - Protocols & Delegates
extension ObservedDetailViewController: UISearchBarDelegate, MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
	
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		if searchText.isEmpty {
			locationResults = []
			suggestionsTableView.isHidden = true
		} else {
			searchCompleter.queryFragment = searchText
		}
	}
	
	func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		if !locationResults.isEmpty { suggestionsTableView.isHidden = false }
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchBar.resignFirstResponder()
		suggestionsTableView.isHidden = true
	}
	
	func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
		locationResults = completer.results
		suggestionsTableView.isHidden = locationResults.isEmpty
		suggestionsTableView.reloadData()
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return locationResults.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
		let item = locationResults[indexPath.row]
		cell.textLabel?.text = item.title + " " + item.subtitle
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = locationResults[indexPath.row]
		Task {
			let request = MKLocalSearch.Request()
			request.naturalLanguageQuery = item.title + " " + item.subtitle
			let search = MKLocalSearch(request: request)
			if let response = try? await search.start(), let place = response.mapItems.first {
				await MainActor.run { self.updateLocationSelection(place.name ?? item.title) }
			}
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.last else { return }
		Task {
			let request = MKReverseGeocodingRequest(location: location)
			if let response = try? await request?.mapItems, let name = response.first?.name {
				await MainActor.run { self.updateLocationSelection(name) }
			}
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

extension ObservedDetailViewController: MapSelectionDelegate {
	func didSelectMapLocation(name: String, lat: Double, lon: Double) {
		updateLocationSelection(name)
	}
}

extension ObservedDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		picker.dismiss(animated: true)
		if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
			birdImageView.image = image
		}
	}
}
