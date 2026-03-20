import UIKit
import MapKit
import CoreLocation
import SwiftData

@MainActor
class ObservedDetailViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource,  MKLocalSearchCompleterDelegate,  CLLocationManagerDelegate, UIGestureRecognizerDelegate {
    
    
    private let manager = WatchlistManager.shared
    private let locationService = LocationService.shared
    var bird: Bird?
    var entry: WatchlistEntry?
    var watchlistId: UUID?
    var shouldUseRuleMatching: Bool = false
    
    var onSave: ((Bird) -> Void)?
    
    private var selectedImageName: String?
    private var selectedLocation: LocationService.LocationData?
    private var locationSuggestions: [LocationService.LocationSuggestion] = []
    
    @IBOutlet weak var suggestionsTableView: UITableView!
    @IBOutlet weak var birdImageContainerView: UIView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var glassBackgroundPlaceholder: UIView!
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var dateTimePicker: UIDatePicker!
    @IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var locationSearchBar: UISearchBar!
    @IBOutlet weak var detailsCardView: UIView!
    @IBOutlet weak var notesCardView: UIView!
    @IBOutlet weak var locationCardView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        if let entry = entry {
            self.title = entry.bird?.commonName ?? "Update Sighting"
            self.bird = entry.bird
        } else {
            self.title = bird?.commonName ?? "Log Sighting"
        }
        
        setupStyling()
        setupSearch()
        setupInteractions()
        
        dateTimePicker.maximumDate = Date()
        
        if let entry = entry {
            configure(with: entry)
            setupRightBarButtons()
        } else if let birdData = bird {
            nameTextField.text = birdData.commonName
            birdImageView.image = UIImage(named: birdData.staticImageName) ?? UIImage(systemName: "photo")
            setupRightBarButtons()
        } else {
            self.navigationItem.title = "Log Sighting"
            birdImageView.image = UIImage(named: "custom.bird.viewfinder.badge.plus")
			birdImageView.tintColor = .systemBlue
			birdImageView.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
            let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
            navigationItem.rightBarButtonItem = saveButton

        }
        
        setupKeyboardHandling()
        setupLocationServices()
        setupLocationOptionsInteractions()
        updateGlassVisibility()
    }
    
    private func setupLocationServices() {
    }
    
    private func setupSearch() {
        locationSearchBar.delegate = self
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        suggestionsTableView.isHidden = true
    }
    
    private func setupLocationOptionsInteractions() {
        guard let container = locationCardView,
              let mainStack = container.subviews.first as? UIStackView,
              mainStack.arrangedSubviews.count >= 3 else {
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
                let alert = UIAlertController(title: "Location Unavailable", message: "Please enable location services in Settings.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
    
    @objc private func didTapMap() {
        let storyboard = UIStoryboard(name:"SharedStoryboard", bundle:nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            mapVC.delegate = self
            navigationController?.pushViewController(mapVC, animated: true)
        } else {
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
    private func setupKeyboardHandling() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
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
        if #available(iOS 26.0, *) {
            let done = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(doneButtonAction))
            doneToolbar.items = [flexSpace, done]
            doneToolbar.sizeToFit()
            nameTextField.inputAccessoryView = doneToolbar
            notesTextView.inputAccessoryView = doneToolbar
        } else {
        }

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
        if let entry = entry {
            let alert = UIAlertController(title: "Delete Observation", message: "Are you sure?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
                do {
                    try self?.manager.deleteEntry(entryId: entry.id)
                    self?.navigationController?.popViewController(animated: true)
                } catch {
                }
            }))
            present(alert, animated: true)
        } else {
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
        guard let name = nameTextField.text, !name.isEmpty else {
            return
        }
        var callbackBird: Bird?
        if let existingEntry = entry {
            do {
                try manager.updateEntry(
                    entryId: existingEntry.id,
                    notes: notesTextView.text,
                    observationDate: dateTimePicker.date,
                    lat: selectedLocation?.lat,
                    lon: selectedLocation?.lon,
                    locationDisplayName: selectedLocation?.displayName
                )
                if let photoName = selectedImageName {
                    try manager.attachPhoto(entryId: existingEntry.id, imageName: photoName)
                }
                if let bird = existingEntry.bird {
                    callbackBird = bird
                }
            } catch {
            }
        } else {
            let birdToUse: Bird
            if let existingBird = bird {
                birdToUse = existingBird
            } else if let found = manager.findBird(byName: name) {
                birdToUse = found
            } else {
                birdToUse = manager.createBird(name: name)
            }
            do {
                let location = selectedLocation.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                
                if shouldUseRuleMatching {
                    let matchedWatchlistIds = try manager.addBirdWithRuleMatching(
                        bird: birdToUse,
                        location: location,
                        observationDate: dateTimePicker.date,
                        notes: notesTextView.text,
                        asObserved: true
                    )
                    if let photoName = selectedImageName {
                        for watchlistId in matchedWatchlistIds {
                            if let entry = try? manager.findEntry(birdId: birdToUse.bird_id, watchlistId: watchlistId) {
                                try manager.attachPhoto(entryId: entry.id, imageName: photoName)
                            }
                        }
                    }
                } else {
                    guard let targetWatchlistId = watchlistId else {
                        return
                    }
                    
                    try manager.addBirds([birdToUse], to: targetWatchlistId, asObserved: true)
                    
                    if let newEntry = try? manager.findEntry(birdId: birdToUse.bird_id, watchlistId: targetWatchlistId) {
                        try manager.updateEntry(
                            entryId: newEntry.id,
                            notes: notesTextView.text,
                            observationDate: dateTimePicker.date,
                            lat: location?.latitude,
                            lon: location?.longitude,
                            locationDisplayName: selectedLocation?.displayName
                        )
                        
                        if let photoName = selectedImageName {
                            try manager.attachPhoto(entryId: newEntry.id, imageName: photoName)
                        }
                    }
                }
                callbackBird = birdToUse
            } catch WatchlistError.noMatchingWatchlists {
                let alert = UIAlertController(
                    title: "No Matching Watchlists",
                    message: "Bird could not find any matching watchlists",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            } catch {
            }
        }
        if let callbackBird, let onSave {
            onSave(callbackBird)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    func configure(with entry: WatchlistEntry) {
        guard let bird = entry.bird else {
            return
        }
        nameTextField.text = bird.commonName
        if let displayName = entry.locationDisplayName {
            let lat = entry.lat
            let lon = entry.lon
            updateLocationSelection(displayName, lat: lat, lon: lon)
        } else if let lat = entry.lat, let lon = entry.lon {
            Task { [weak self] in
                guard let self else { return }
                let name = await locationService.reverseGeocode(lat: lat, lon: lon) ?? "Location"
                await MainActor.run {
                    self.updateLocationSelection(name, lat: lat, lon: lon)
                }
            }
        } else {
            updateLocationSelection(bird.likelySpot ?? "")
        }
        birdImageView.image = ObservedDetailViewController.loadImage(for: entry)
        
        if let date = entry.observationDate {
            dateTimePicker.date = date
        }
        notesTextView.text = entry.notes
    }
    private static func loadImage(for entry: WatchlistEntry) -> UIImage {
        if let photoPath = entry.photos?.first?.imagePath {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let photoDir = documentsDir.appendingPathComponent("ObservedBirdPhotos", isDirectory: true)
            let fileURL = photoDir.appendingPathComponent(photoPath)
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
        styleCard(glassBackgroundPlaceholder)
        
        if let button = glassBackgroundPlaceholder as? UIButton {
            button.configuration = .plain()
            button.addTarget(self, action: #selector(didTapGlassButton), for: .touchUpInside)
        }
        
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
    
    @objc private func didTapGlassButton() {
        glassBackgroundPlaceholder.isHidden = true
        birdImageView.isHidden = false
        didTapImage()
    }
    
    private func updateGlassVisibility() {
        let isPlaceholder = isUsingPlaceholder()
        glassBackgroundPlaceholder.isHidden = !isPlaceholder
        
        if isPlaceholder {
        } else {
            birdImageView.tintColor = nil
        }

        birdImageView.isHidden = false
    }
    
    private func isUsingPlaceholder() -> Bool {
        guard let image = birdImageView.image else { 
            return true 
        }
        let isSymbol = image.isSymbolImage
        return isSymbol
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
    extension ObservedDetailViewController{
        
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
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return locationSuggestions.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
            let item = locationSuggestions[indexPath.row]
            cell.textLabel?.text = item.fullText
            let isDarkMode = traitCollection.userInterfaceStyle == .dark
            cell.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
            cell.textLabel?.textColor = .label
            return cell
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let item = locationSuggestions[indexPath.row]
            let fullLocationText = item.fullText
            suggestionsTableView.isHidden = true
            locationSearchBar.resignFirstResponder()
            
            Task {
                do {
                    let location = try await locationService.geocode(query: fullLocationText)
                    let finalLocation = LocationService.LocationData(
                        displayName: fullLocationText,
                        lat: location.lat,
                        lon: location.lon
                    )
                    
                    await MainActor.run {
                        self.updateLocationSelection(finalLocation)
                    }
                } catch {
                    await MainActor.run {
                        self.updateLocationSelection(fullLocationText, lat: nil, lon: nil)
                    }
                }
            }
        }
        
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if touch.view?.isDescendant(of: suggestionsTableView) == true {
                return false
            }
            return true
        }
    }
    
    extension ObservedDetailViewController: MapSelectionDelegate {
        func didSelectMapLocation(name: String, lat: Double, lon: Double) {
            updateLocationSelection(name, lat: lat, lon: lon)
        }
    }
    
    extension ObservedDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else { return }
            
            birdImageView.image = image
            updateGlassVisibility()
            let filename = "bird_photo_\(UUID().uuidString).png"
            if let data = image.jpegData(compressionQuality: 0.8) {
                let fileManager = FileManager.default
                guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    return
                }
                
                let photoDir = documentsURL.appendingPathComponent("ObservedBirdPhotos", isDirectory: true)
                let fileURL = photoDir.appendingPathComponent(filename)
                
                do {
                    if !fileManager.fileExists(atPath: photoDir.path) {
                        try fileManager.createDirectory(at: photoDir, withIntermediateDirectories: true)
                    }
                    
                    try data.write(to: fileURL)
                    selectedImageName = filename
                } catch {
                }
            }
        }
    }
