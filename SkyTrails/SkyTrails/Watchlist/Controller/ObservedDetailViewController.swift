import UIKit
import MapKit
import CoreLocation
import SwiftData

@MainActor
class ObservedDetailViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, MKLocalSearchCompleterDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {
    
    
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

    // One-shot guards: prevents repeatedly advancing the step on every keystroke / picker scroll
    private var hasAdvancedFromDatePicker = false
    private var hasAdvancedFromNotes = false

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
		self.navigationItem.largeTitleDisplayMode = .automatic
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
        // Date picker: advancing step when user changes the date
        dateTimePicker.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)
        // Notes text view delegate for step advance
        notesTextView.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Reset one-shot guards for a fresh tooltip sequence
        hasAdvancedFromDatePicker = false
        hasAdvancedFromNotes = false
        IdentificationTooltipManager.shared.scheduleStepByStepTooltips(in: self.view, steps: [
            (message: "Tap the bird image to add a photo of your sighting.",
             targetProvider: { [weak self] in self?.birdImageView }),
            (message: "Enter or confirm the bird's name.",
             targetProvider: { [weak self] in self?.nameTextField }),
            (message: "Set when you observed the bird.",
             targetProvider: { [weak self] in self?.dateTimePicker }),
            (message: "Search for where you spotted it.",
             targetProvider: { [weak self] in self?.locationSearchBar }),
            (message: "Add any notes about your observation.",
             targetProvider: { [weak self] in self?.notesTextView }),
            (message: "Tap Save to record your sighting.",
             targetProvider: { [weak self] in
                 (self?.navigationItem.rightBarButtonItems?.first ?? self?.navigationItem.rightBarButtonItem)?.value(forKey: "view") as? UIView
             })
        ])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IdentificationTooltipManager.shared.cancelTooltip()
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
            WatchlistLog.warn("Failed to instantiate MapViewController from SharedStoryboard")
        }
    }
    
    private func updateLocationSelection(_ location: LocationService.LocationData) {
        locationSearchBar.text = location.displayName
        selectedLocation = location
        suggestionsTableView.isHidden = true
        locationSearchBar.resignFirstResponder()
        IdentificationTooltipManager.shared.advanceToNextStep()
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
        IdentificationTooltipManager.shared.advanceToNextStep()
    }
    private func setupKeyboardHandling() {
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
        suggestionsTableView.isHidden = true
    }

    @objc private func datePickerChanged() {
        guard !hasAdvancedFromDatePicker else { return }
        hasAdvancedFromDatePicker = true
        IdentificationTooltipManager.shared.advanceToNextStep()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        IdentificationTooltipManager.shared.advanceToNextStep()
        return true
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
                    WatchlistLog.error("Failed to delete observed entry", error: error)
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
        // Don't cancel — tapping the image advances to next step (name field)
        // The advance will happen when the image is actually picked (imagePickerController delegate)
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    @objc func didTapSave() {
        IdentificationTooltipManager.shared.cancelTooltip()
        guard let name = nameTextField.text, !name.isEmpty else { return }
        
        Task {
            let params = WatchlistEntryOrchestrationService.SaveParameters(
                entry: entry,
                bird: bird,
                birdName: name,
                watchlistId: watchlistId,
                notes: notesTextView.text,
                location: selectedLocation,
                observationDate: dateTimePicker.date,
                endDate: nil,
                photoName: selectedImageName,
                asObserved: true,
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
                if let onSave {
                    onSave(callbackBird)
                } else {
                    navigationController?.popViewController(animated: true)
                }
            } else {
                navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func configure(with entry: WatchlistEntry) {
        guard let bird = entry.bird else {
            return
        }
        nameTextField.text = bird.commonName
        
        if let displayName = entry.locationDisplayName, !displayName.isEmpty {
            updateLocationSelection(displayName, lat: entry.lat, lon: entry.lon)
        } else if let lat = entry.lat, let lon = entry.lon {
            Task { [weak self] in
                guard let self else { return }
                let name = await locationService.reverseGeocode(lat: lat, lon: lon) ?? "Location"
                await MainActor.run {
                    self.updateLocationSelection(name, lat: lat, lon: lon)
                }
            }
        } else if let likelySpot = bird.likelySpot, !likelySpot.isEmpty {
            updateLocationSelection(likelySpot)
        }
        
        // Use consistent image loading via WatchlistManager (though here we display directly)
        Task {
            let image = await manager.loadImageForEntry(entry)
            birdImageView.image = image
            updateGlassVisibility()
        }
        
        if let date = entry.observationDate {
            dateTimePicker.date = date
        }
        notesTextView.text = entry.notes
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
            // Image picked — advance to the name field step
            IdentificationTooltipManager.shared.advanceToNextStep()
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
                    WatchlistLog.error("Failed to persist selected observation photo", error: error)
                }
            }
        }
    }

extension ObservedDetailViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView == notesTextView, !hasAdvancedFromNotes {
            hasAdvancedFromNotes = true
            IdentificationTooltipManager.shared.advanceToNextStep()
        }
    }
}
