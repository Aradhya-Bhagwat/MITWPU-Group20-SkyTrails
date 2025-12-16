//
//  ObservedDetailViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 09/12/25.
//

import UIKit
import MapKit
import CoreLocation

class ObservedDetailViewController: UIViewController {
    
    // MARK: - Data Dependency
    var bird: Bird? // nil if adding new
    var watchlistId: UUID?
    // weak var viewModel: WatchlistViewModel? // Removed
    var onSave: ((Bird) -> Void)?
    
    private let locationManager = CLLocationManager()

    private var selectedImageName: String?
    
    // Autocomplete State
    private var searchCompleter = MKLocalSearchCompleter()
    private var locationResults: [MKLocalSearchCompletion] = []
    
    private var allBirdNames: [String] = []
    private var filteredBirdNames: [String] = []
    
    // Track which input is currently driving suggestions
    private enum InputType {
        case location
        case name
        case none
    }
    
    private var currentInputType: InputType = .none
    
    @IBOutlet weak var suggestionsTableView: UITableView!
    
    // MARK: - IBOutlets
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
        setupData()
        setupInteractions()
        
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
        nameTextField.delegate = self
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
    }
    
    private func setupLocationOptionsInteractions() {
        guard let container = locationCardView else { return }
        
        if let mainStack = container.subviews.first as? UIStackView, mainStack.arrangedSubviews.count >= 3 {
            let currentLocationView = mainStack.arrangedSubviews[0]
            let mapView = mainStack.arrangedSubviews[2]
            
            let locationTap = UITapGestureRecognizer(target: self, action: #selector(didTapCurrentLocation))
            currentLocationView.isUserInteractionEnabled = true
            currentLocationView.addGestureRecognizer(locationTap)
            
            let mapTap = UITapGestureRecognizer(target: self, action: #selector(didTapMap))
            mapView.isUserInteractionEnabled = true
            mapView.addGestureRecognizer(mapTap)
        }
    }
    
    @objc private func didTapCurrentLocation() {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            let alert = UIAlertController(title: "Location Access Denied", message: "Please enable location services in Settings to use this feature.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        @unknown default:
            break
        }
    }
    
    @objc private func didTapMap() {
        let storyboard = UIStoryboard(name:"SharedStoryboard",bundle:nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            mapVC.delegate = self
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    private func updateLocationSelection(_ name: String) {
        locationSearchBar.text = name
        suggestionsTableView.isHidden = true
        currentInputType = .none
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
    }
    
    private func addDoneButtonOnKeyboard() {
        let doneToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.window?.windowScene?.screen.bounds.width ?? view.bounds.width, height: 50))
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(doneButtonAction))
        
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
        deleteBird()
    }
    
    private func deleteBird() {
        guard let birdToDelete = bird, let id = watchlistId else { return }
        
        let alert = UIAlertController(title: "Delete Observation", message: "Are you sure you want to delete this observation?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            WatchlistManager.shared.deleteBird(birdToDelete, from: id)
            self?.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
    }
    
    private func setupData() {
        let watchlists = WatchlistManager.shared.watchlists
        let birds = watchlists.flatMap { $0.birds }
        self.allBirdNames = Array(Set(birds.map { $0.name })).sorted()
    }
    
    private func setupInteractions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapImage))
        birdImageView.isUserInteractionEnabled = true
        birdImageView.addGestureRecognizer(tapGesture)
    }
    
    @objc func didTapImage() {
        print("did tap recoginsed")
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    @objc func didTapSave() {
        guard let name = nameTextField.text, !name.isEmpty else {
            let alert = UIAlertController(title: "Missing Info", message: "Please enter a bird name.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        var images: [String] = []
        if let imgName = selectedImageName {
            images.append(imgName)
        } else if let existing = bird?.images.first {
            images.append(existing)
        } else {
            images.append("bird_placeholder")
        }
        
        let loc = locationSearchBar.text ?? "Unknown Location"
        
        let idToUse = bird?.id ?? UUID()
        
        let newBird = Bird(
            id: idToUse,
            name: name,
            scientificName: "Unknown",
            images: images,
            rarity: [.common],
            location: [loc],
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
            if let assetImage = UIImage(named: imageName) {
                birdImageView.image = assetImage
            } else {
                let fileURL = getDocumentsDirectory().appendingPathComponent(imageName)
                if let docImage = UIImage(contentsOfFile: fileURL.path) {
                    birdImageView.image = docImage
                } else {
                    birdImageView.image = UIImage(systemName: "photo")
                }
            }
        } else {
            birdImageView.image = UIImage(systemName: "photo")
        }
        
        if let date = bird.date.first {
            dateTimePicker.date = date
        }
        
        notesTextView.text = bird.notes
    }
    
    func setupStyling() {
        view.backgroundColor = .systemGray6
        
        birdImageView.layer.cornerRadius = 24
        birdImageView.clipsToBounds = true
        birdImageView.contentMode = .scaleAspectFill
        
        styleCard(detailsCardView)
        styleCard(notesCardView)
        styleCard(locationCardView)
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

// MARK: - Delegates
extension ObservedDetailViewController: UITextFieldDelegate, UISearchBarDelegate, MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
    
    // MARK: - Search Bar (Location)
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentInputType = .location
        if searchText.isEmpty {
            locationResults = []
            suggestionsTableView.isHidden = true
        } else {
            searchCompleter.queryFragment = searchText
        }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        currentInputType = .location
        suggestionsTableView.isHidden = false
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        suggestionsTableView.isHidden = true
        currentInputType = .none
    }
    
    // MARK: - Text Field (Name)
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == nameTextField {
            currentInputType = .name
            suggestionsTableView.isHidden = false
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) else { return true }
        
        if textField == nameTextField {
            currentInputType = .name
            filterBirdNames(query: text)
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // If we are moving focus to the other field, the other didBeginEditing will set the type.
        // If we are just dismissing, we can clear it after a short delay or let tap gesture handle it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Check if focus moved to search bar
            if !self.locationSearchBar.isFirstResponder && !self.nameTextField.isFirstResponder {
                self.suggestionsTableView.isHidden = true
                self.currentInputType = .none
            }
        }
    }
    
    // MARK: - Autocomplete Logic
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Only update if location is the active input
        if currentInputType == .location {
            locationResults = completer.results
            suggestionsTableView.isHidden = locationResults.isEmpty
            suggestionsTableView.reloadData()
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // print("Error")
    }
    
    private func filterBirdNames(query: String) {
        if query.isEmpty {
            filteredBirdNames = []
            suggestionsTableView.isHidden = true
        } else {
            filteredBirdNames = allBirdNames.filter { $0.localizedCaseInsensitiveContains(query) }
            suggestionsTableView.isHidden = filteredBirdNames.isEmpty
        }
        suggestionsTableView.reloadData()
    }
    
    // MARK: - Table View
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentInputType {
        case .location:
            return locationResults.count
        case .name:
            return filteredBirdNames.count
        case .none:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
        cell.backgroundColor = .white
        cell.textLabel?.textColor = .black
        
        switch currentInputType {
        case .location:
            if indexPath.row < locationResults.count {
                let item = locationResults[indexPath.row]
                cell.textLabel?.text = item.title + " " + item.subtitle
            }
        case .name:
            if indexPath.row < filteredBirdNames.count {
                cell.textLabel?.text = filteredBirdNames[indexPath.row]
            }
        case .none:
            cell.textLabel?.text = ""
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if currentInputType == .location {
            if indexPath.row < locationResults.count {
                let item = locationResults[indexPath.row]
                
                // Modern Async Search
                Task {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = item.title + " " + item.subtitle
                    let search = MKLocalSearch(request: request)
                    
                    do {
                        let response = try await search.start()
                        if let place = response.mapItems.first {
                            let name = place.name ?? item.title
                            await MainActor.run {
                                self.updateLocationSelection(name)
                            }
                        }
                    } catch {
                        print("Search failed: \(error.localizedDescription)")
                    }
                }
            }
        } else if currentInputType == .name {
            if indexPath.row < filteredBirdNames.count {
                let name = filteredBirdNames[indexPath.row]
                nameTextField.text = name
                suggestionsTableView.isHidden = true
                currentInputType = .none
                nameTextField.resignFirstResponder()
            }
        }
    }

    // MARK: - CoreLocation Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { [weak self] in
            guard let self else { return }

            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    await MainActor.run {
                        self.updateLocationSelection("Location")
                    }
                    return
                }
                let response = try await request.mapItems
                let item = response.first

                let name = item?.name ?? "Location"

                await MainActor.run {
                    self.updateLocationSelection(name)
                }

            } catch {
                await MainActor.run {
                    self.updateLocationSelection("Location")
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

extension ObservedDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(_ locationName: String) {
        updateLocationSelection(locationName)
    }
}

// MARK: - Image Picker Delegate
extension ObservedDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else { return }
        
        birdImageView.image = image
        
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
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
