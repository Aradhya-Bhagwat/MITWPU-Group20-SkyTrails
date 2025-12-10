	//
	//  ObservedDetailViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 09/12/25.
	//

import UIKit
import MapKit
import CoreLocation

class ObservedDetailViewController: UIViewController, CLLocationManagerDelegate {
	
		// MARK: - Data Dependency
	var bird: Bird? // nil if adding new
	var watchlistId: UUID?
	weak var coordinator: WatchlistCoordinator?
	weak var viewModel: WatchlistViewModel?
	
	private let locationManager = CLLocationManager()
	
	private var selectedImageName: String?
	
		// Autocomplete State
	private var searchCompleter = MKLocalSearchCompleter()
	private var locationResults: [MKLocalSearchCompletion] = []
	
	private var allBirdNames: [String] = []
	private var filteredBirdNames: [String] = []
	
	@IBOutlet weak var locationStack: UIStackView!
	private var activeTextField: UITextField?
	private lazy var suggestionsTableView: UITableView = {
		let tv = UITableView()
		tv.translatesAutoresizingMaskIntoConstraints = false
		tv.backgroundColor = .white
		tv.layer.cornerRadius = 12
		tv.layer.shadowColor = UIColor.black.cgColor
		tv.layer.shadowOpacity = 0.1
		tv.layer.shadowOffset = CGSize(width: 0, height: 4)
		tv.layer.shadowRadius = 8
		tv.isHidden = true
		tv.delegate = self
		tv.dataSource = self
		tv.separatorStyle = .none
		tv.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell")
		return tv
	}()
	
		// MARK: - IBOutlets
	@IBOutlet weak var birdImageView: UIImageView!
	@IBOutlet weak var dateLabel: UILabel!
	
	@IBOutlet weak var dateTimePicker: UIDatePicker!
	
	@IBOutlet weak var notesTextView: UITextView!
	@IBOutlet weak var searchTextField: UITextField! // Name Field
	@IBOutlet weak var locationTextField: UITextField! // New Location Field
	
	@IBOutlet weak var detailsCardView: UIView!
	@IBOutlet weak var notesCardView: UIView!
	@IBOutlet weak var locationCardView: UIView!
	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		self.title = bird?.name
		setupStyling()
		setupInteractions()
		setupAutocomplete()
		setupData()
		
			// Load data if editing existing
		if let birdData = bird {
			configure(with: birdData)
			setupRightBarButtons()
		} else {
				// New Entry Setup
			self.navigationItem.title = "New Observation"
			birdImageView.image = UIImage(systemName: "camera.fill")
			birdImageView.tintColor = .systemGray
			
				// Save Button for new entry
			let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
			navigationItem.rightBarButtonItem = saveButton
		}
		
		setupKeyboardHandling()
		setupLocationManager()
			// REMOVED: setupLocationButton() call
	}
	
	private func setupLocationManager() {
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.requestWhenInUseAuthorization()
	}
	
		// REMOVED: private func setupLocationButton() { ... }
	
	@objc private func didTapCurrentLocation() {
			// Optional: Add visual feedback (like an activity indicator) here if desired
		locationManager.requestLocation()
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.last else { return }
		
		let geocoder = CLGeocoder()
		geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
			guard let self = self else { return }
			if let error = error {
				print("Reverse geocoding failed: \(error.localizedDescription)")
				return
			}
			
			if let placemark = placemarks?.first {
				let city = placemark.locality ?? ""
				let area = placemark.subLocality ?? ""
				let country = placemark.country ?? ""
				
				var address = ""
				if !area.isEmpty { address += area + ", " }
				if !city.isEmpty { address += city + ", " }
				address += country
				
				DispatchQueue.main.async {
					self.locationTextField.text = address
				}
			}
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		print("Location manager failed: \(error.localizedDescription)")
	}
	
		// MARK: - Keyboard Handling
	
	private var mainScrollView: UIScrollView? {
			// Try to find the main scroll view, excluding the suggestions table view
		return view.subviews.first(where: { $0 is UIScrollView && $0 !== suggestionsTableView }) as? UIScrollView
	}
	
	private func setupKeyboardHandling() {
		addDoneButtonOnKeyboard()
		
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	private func addDoneButtonOnKeyboard() {
		let doneToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
		doneToolbar.barStyle = .default
		
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonAction))
		
		doneToolbar.items = [flexSpace, done]
		doneToolbar.sizeToFit()
		
		searchTextField.inputAccessoryView = doneToolbar
		locationTextField.inputAccessoryView = doneToolbar
		notesTextView.inputAccessoryView = doneToolbar
	}
	
	@objc func doneButtonAction() {
		view.endEditing(true)
	}
	
	@objc func keyboardWillShow(notification: NSNotification) {
		guard let userInfo = notification.userInfo,
			  let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
			  let scrollView = mainScrollView else { return }
		
		let keyboardHeight = keyboardFrame.height
		var contentInset = scrollView.contentInset
		contentInset.bottom = keyboardHeight
		scrollView.contentInset = contentInset
		scrollView.verticalScrollIndicatorInsets = contentInset
	}
	
	@objc func keyboardWillHide(notification: NSNotification) {
		guard let scrollView = mainScrollView else { return }
		
		var contentInset = scrollView.contentInset
		contentInset.bottom = 0
		scrollView.contentInset = contentInset
		scrollView.verticalScrollIndicatorInsets = contentInset
	}
	
	private func setupRightBarButtons() {
		let deleteButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(didTapDelete))
		deleteButton.tintColor = .systemRed // Optional: Make trash icon red
		
		let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
		
			// Order: Right to Left -> [Save, Delete]
		navigationItem.rightBarButtonItems = [saveButton, deleteButton]
	}
	
	@objc private func didTapDelete() {
		deleteBird()
	}
	
	private func deleteBird() {
		guard let birdToDelete = bird, let id = watchlistId else { return }
		
		let alert = UIAlertController(title: "Delete Observation", message: "Are you sure you want to delete this observation?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
			if let vm = self?.viewModel {
				vm.deleteBird(birdToDelete, from: id)
			} else {
				self?.coordinator?.viewModel?.deleteBird(birdToDelete, from: id)
			}
			self?.navigationController?.popViewController(animated: true)
		}))
		present(alert, animated: true)
	}
	
	private func setupData() {
			// Extract unique bird names from mock data
		let watchlists = createMockWatchlists()
		let birds = watchlists.flatMap { $0.birds }
		self.allBirdNames = Array(Set(birds.map { $0.name })).sorted()
	}
	
	private func setupAutocomplete() {
		searchCompleter.delegate = self
		searchTextField.delegate = self
		locationTextField.delegate = self
		
		view.addSubview(suggestionsTableView)
		view.bringSubviewToFront(suggestionsTableView)
	}
	
	private func setupInteractions() {
			// Image Tap Gesture
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapImage))
		birdImageView.isUserInteractionEnabled = true
		birdImageView.addGestureRecognizer(tapGesture)
		
			// CHANGED: Location Stack Tap Gesture
			// 1. Enable interaction (StackViews are false by default)
		locationStack.isUserInteractionEnabled = true
			// 2. Add Gesture
		let locationTapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapCurrentLocation))
		locationStack.addGestureRecognizer(locationTapGesture)
	}
	
	private func updateSuggestionsLayout() {
		guard let activeTF = activeTextField, !suggestionsTableView.isHidden else { return }
		
			// Convert text field frame to main view coordinates
		let frame = activeTF.convert(activeTF.bounds, to: view)
		
			// Update constraints (remake them)
		suggestionsTableView.removeConstraints(suggestionsTableView.constraints)
		view.removeConstraints(view.constraints.filter { $0.firstItem as? UIView == suggestionsTableView })
		
		NSLayoutConstraint.activate([
			suggestionsTableView.topAnchor.constraint(equalTo: view.topAnchor, constant: frame.maxY + 4),
			suggestionsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: frame.minX),
			suggestionsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(view.bounds.width - frame.maxX)),
			suggestionsTableView.heightAnchor.constraint(equalToConstant: 200) // Fixed height for suggestions
		])
	}
	
	@objc func didTapImage() {
		let picker = UIImagePickerController()
		picker.sourceType = .photoLibrary // Or .camera
		picker.delegate = self
		picker.allowsEditing = true
		present(picker, animated: true)
	}
	
	@objc func didTapSave() {
		guard let name = searchTextField.text, !name.isEmpty else {
			let alert = UIAlertController(title: "Missing Info", message: "Please enter a bird name.", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default))
			present(alert, animated: true)
			return
		}
		
			// 1. Create Image Array (use selected image or default)
		var images: [String] = []
		if let imgName = selectedImageName {
			images.append(imgName)
		} else if let existing = bird?.images.first {
			images.append(existing)
		} else {
			images.append("bird_placeholder") // Ensure you have a placeholder asset or handle nil
		}
		
			// 2. Location
		let loc = locationTextField.text ?? "Unknown Location"
		
			// 3. Create the New Bird Object
		let idToUse = bird?.id ?? UUID()
		
		let newBird = Bird(
			id: idToUse,
			name: name,
			scientificName: "Unknown", // Default
			images: images,
			rarity: [.common], // Default
			location: [loc],
			date: [dateTimePicker.date],
			observedBy: ["person.circle.fill"], // Current user
			notes: notesTextView.text
		)
		
			// 4. Pass back to Coordinator or ViewModel
		if let vm = viewModel, let wId = watchlistId {
			vm.saveObservation(bird: newBird, watchlistId: wId)
			navigationController?.popViewController(animated: true)
		} else {
			coordinator?.saveBirdDetails(bird: newBird)
		}
	}
	
		// MARK: - Configuration
	func configure(with bird: Bird) {
		searchTextField.text = bird.name
		locationTextField.text = bird.location.first
		
		if let imageName = bird.images.first {
			if let assetImage = UIImage(named: imageName) {
				birdImageView.image = assetImage
			} else {
				let fileURL = getDocumentsDirectory().appendingPathComponent(imageName)
				if let docImage = UIImage(contentsOfFile: fileURL.path) {
					birdImageView.image = docImage
				}
			}
		}
		if let date = bird.date.first {
			dateTimePicker.date = date
		}
		
		notesTextView.text = bird.notes
	}
	
		// MARK: - Styling
	func setupStyling() {
		view.backgroundColor = .systemGray6
		
			// Fix for white view showing behind rounded corners
		
		
		birdImageView.layer.cornerRadius = 24
		birdImageView.clipsToBounds = true
		birdImageView.contentMode = .scaleAspectFill
		
		searchTextField.layer.cornerRadius = 8
		searchTextField.layer.masksToBounds = true
		
		locationTextField.layer.cornerRadius = 8
		locationTextField.layer.masksToBounds = true
		
		styleCard(detailsCardView)
		if let notesView = notesCardView {
			styleCard(notesView)
		}
		
	}
	
	func styleCard(_ view: UIView) {
		view.layer.cornerRadius = 20
		view.backgroundColor = .white
		view.layer.shadowColor = UIColor.black.cgColor
		view.layer.shadowOpacity = 0.08
		view.layer.shadowOffset = CGSize(width: 0, height: 4)
		view.layer.shadowRadius = 12
		view.layer.masksToBounds = false
	}
}

// MARK: - Text Field & Autocomplete Delegate
extension ObservedDetailViewController: UITextFieldDelegate, MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate {
	
	func textFieldDidBeginEditing(_ textField: UITextField) {
		activeTextField = textField
		updateSuggestionsLayout()
	}
	
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		guard let text = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) else { return true }
		
		if textField == locationTextField {
			searchCompleter.queryFragment = text
				// Table visibility handled in delegate
		} else if textField == searchTextField {
			filterBirdNames(query: text)
		}
		
		return true
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
			// Delay hiding to allow selection
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			if self.activeTextField == textField {
				self.suggestionsTableView.isHidden = true
			}
		}
	}
	
		// MARK: - MapKit Delegate
	func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
		locationResults = completer.results
		if activeTextField == locationTextField {
			suggestionsTableView.isHidden = locationResults.isEmpty
			suggestionsTableView.reloadData()
			updateSuggestionsLayout()
		}
	}
	
	func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
		print("Location Search Error: \(error.localizedDescription)")
	}
	
		// MARK: - Bird Name Filtering
	private func filterBirdNames(query: String) {
		if query.isEmpty {
			filteredBirdNames = []
			suggestionsTableView.isHidden = true
		} else {
			filteredBirdNames = allBirdNames.filter { $0.localizedCaseInsensitiveContains(query) }
			suggestionsTableView.isHidden = filteredBirdNames.isEmpty
		}
		suggestionsTableView.reloadData()
		updateSuggestionsLayout()
	}
	
		// MARK: - Table View Data Source
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if activeTextField == locationTextField {
			return locationResults.count
		} else {
			return filteredBirdNames.count
		}
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
		cell.backgroundColor = .white
		cell.textLabel?.textColor = .black
		
		if activeTextField == locationTextField {
			let result = locationResults[indexPath.row]
			cell.textLabel?.text = result.title + ", " + result.subtitle
		} else {
			cell.textLabel?.text = filteredBirdNames[indexPath.row]
		}
		
		return cell
	}
	
		// MARK: - Table View Delegate
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		if activeTextField == locationTextField {
			let result = locationResults[indexPath.row]
			
				// Perform search to get full details (like coordinate)
			let searchRequest = MKLocalSearch.Request(completion: result)
			let search = MKLocalSearch(request: searchRequest)
			
			search.start { [weak self] (response, error) in
				guard let self = self, let response = response else { return }
				
					// Use the name + subtitle or formatted address
					// For simplicity, using the title + subtitle
				let fullAddress = result.title + " " + result.subtitle
				self.locationTextField.text = fullAddress
				
					// You can save response.mapItem.placemark.coordinate here if needed
				
				self.suggestionsTableView.isHidden = true
				self.activeTextField?.resignFirstResponder()
			}
		} else {
			let name = filteredBirdNames[indexPath.row]
			searchTextField.text = name
			suggestionsTableView.isHidden = true
			activeTextField?.resignFirstResponder()
		}
	}
}

// MARK: - Image Picker Delegate
extension ObservedDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		picker.dismiss(animated: true)
		
		guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else { return }
		
			// 1. Update UI
		birdImageView.image = image
		
			// 2. Save to Disk and get filename
		if let filename = saveImageToDocuments(image) {
			self.selectedImageName = filename
		}
	}
	
	private func saveImageToDocuments(_ image: UIImage) -> String? {
		guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
		let filename = UUID().uuidString + ".jpg"
		let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
		
		do {
			try data.write(to: fileURL)
			return filename // This string matches the `Bird` model `images` array expectation
		} catch {
			print("Error saving image: \(error)")
			return nil
		}
	}
	
	private func getDocumentsDirectory() -> URL {
		return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}
}
