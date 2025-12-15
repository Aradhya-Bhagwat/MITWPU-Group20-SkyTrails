import UIKit
import MapKit
import CoreLocation

class UnobservedDetailViewController: UIViewController {
    
    // MARK: - Dependencies
    var bird: Bird?
    var watchlistId: UUID?
    var onSave: ((Bird) -> Void)?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var searchCompleter = MKLocalSearchCompleter()
    private var locationResults: [MKLocalSearchCompletion] = []
    
    // MARK: - IBOutlets
    @IBOutlet weak var suggestionsTableView: UITableView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var endLabel: UILabel!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    @IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
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
        view.backgroundColor = .systemGray6
        
        birdImageView.layer.cornerRadius = 24
        birdImageView.clipsToBounds = true
        
        styleCard(detailsCardView)
        styleCard(locationCardView)
        
        setupLocationOptionsInteractions()
        setupNavigationItems()
    }
    
    private func styleCard(_ view: UIView) {
        view.layer.cornerRadius = 20
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.masksToBounds = false
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
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupSearch() {
        searchCompleter.delegate = self
        locationSearchBar.delegate = self
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
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
        nameTextField.text = bird.name
        loadImage(for: bird)
        
        if let firstDate = bird.date.first { startDatePicker.date = firstDate }
        if let lastDate = bird.date.last { endDatePicker.date = lastDate }
        
        locationSearchBar.text = bird.location.first
        notesTextView.text = bird.notes ?? "Add notes..."
    }
    
    private func loadImage(for bird: Bird) {
        if let imageName = bird.images.first {
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
        } else {
            birdImageView.image = UIImage(systemName: "photo")
        }
    }
    
    // MARK: - Actions
    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
        let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            mapVC.delegate = self
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    @objc private func didTapDelete() {
        guard let bird = bird, let id = watchlistId else { return }
        
        let alert = UIAlertController(title: "Delete Bird", message: "Delete this bird from watchlist?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            WatchlistManager.shared.deleteBird(bird, from: id)
            self?.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
    }
    
    @objc private func didTapSave() {
        let name = nameTextField.text ?? (bird?.name ?? "Unknown Bird")
        let location = locationSearchBar.text ?? ""
        let notes = notesTextView.text
        
        var updatedBird = bird ?? Bird(name: name, scientificName: "", images: [], rarity: [.common], location: [], date: [], observedBy: nil)
        
        updatedBird.name = name
        if !location.isEmpty {
            updatedBird.location = [location]
        }
        updatedBird.date = [startDatePicker.date, endDatePicker.date]
        updatedBird.notes = notes
        
        if let wId = watchlistId {
            WatchlistManager.shared.updateBird(updatedBird, watchlistId: wId)
            navigationController?.popViewController(animated: true)
        } else {
            onSave?(updatedBird)
        }
    }
    
    private func updateLocationSelection(_ name: String) {
        locationSearchBar.text = name
        suggestionsTableView.isHidden = true
        locationSearchBar.resignFirstResponder()
    }
}

// MARK: - CLLocationManagerDelegate
extension UnobservedDetailViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Modern Async Geocoding
        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    let city = placemark.locality ?? ""
                    let area = placemark.subLocality ?? ""
                    let country = placemark.country ?? ""
                    
                    let parts = [area, city, country].filter { !$0.isEmpty }
                    let address = parts.joined(separator: ", ")
                    
                    await MainActor.run {
                        self.updateLocationSelection(address)
                    }
                }
            } catch {
                print("Reverse geocoding failed: \(error.localizedDescription)")
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

// MARK: - UITableViewDelegate & DataSource
extension UnobservedDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
        let result = locationResults[indexPath.row]
        
        cell.backgroundColor = .white
        cell.textLabel?.textColor = .black
        cell.textLabel?.text = "\(result.title) \(result.subtitle)"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
}

// MARK: - UISearchBarDelegate
extension UnobservedDetailViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            locationResults = []
            suggestionsTableView.isHidden = true
        } else {
            searchCompleter.queryFragment = searchText
        }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        suggestionsTableView.isHidden = false
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        suggestionsTableView.isHidden = true
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension UnobservedDetailViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        locationResults = completer.results
        suggestionsTableView.isHidden = locationResults.isEmpty
        suggestionsTableView.reloadData()
    }
}

// MARK: - MapSelectionDelegate
extension UnobservedDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(_ locationName: String) {
        updateLocationSelection(locationName)
    }
}