import UIKit
import MapKit
import CoreLocation

class UnobservedDetailViewController: UIViewController, CLLocationManagerDelegate {
    
    // MARK: - Data Dependency
    var bird: Bird?
    var watchlistId: UUID?
    weak var coordinator: WatchlistCoordinator?
    weak var viewModel: WatchlistViewModel?
    
    private let locationManager = CLLocationManager()
    
    // Autocomplete State
    private var searchCompleter = MKLocalSearchCompleter()
    private var locationResults: [MKLocalSearchCompletion] = []
    
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
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var endLabel: UILabel!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    @IBOutlet weak var notesTextView: UITextView!
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var locationSearchBar: UISearchBar!
    
    @IBOutlet weak var detailsCardView: UIView!
    @IBOutlet weak var locationCardView: UIView! // Acts as locationOptionsContainer
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = bird?.name
        
        setupStyling()
        setupSearch()
        
        if let birdData = bird {
            configure(with: birdData)
            setupRightBarButtons()
        } else {
            let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
            navigationItem.rightBarButtonItem = saveButton
        }
        
        setupKeyboardHandling()
        setupLocationManager()
        setupLocationOptionsInteractions()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupSearch() {
        searchCompleter.delegate = self
        locationSearchBar.delegate = self
        
        view.addSubview(suggestionsTableView)
    }
    
    private func setupLocationOptionsInteractions() {
        guard let container = locationCardView else { return }
        
        // Assuming structure: StackView -> [CurrentLocationStack, Separator, MapStack]
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
    
    private func updateSuggestionsLayout() {
        guard !suggestionsTableView.isHidden else { return }
        
        let frame = locationSearchBar.convert(locationSearchBar.bounds, to: view)
        
        suggestionsTableView.removeConstraints(suggestionsTableView.constraints)
        view.removeConstraints(view.constraints.filter { $0.firstItem as? UIView == suggestionsTableView })
        
        NSLayoutConstraint.activate([
            suggestionsTableView.topAnchor.constraint(equalTo: view.topAnchor, constant: frame.maxY + 4),
            suggestionsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: frame.minX),
            suggestionsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(view.bounds.width - frame.maxX)),
            suggestionsTableView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        view.bringSubviewToFront(suggestionsTableView)
    }
    
    @objc private func didTapCurrentLocation() {
        locationManager.requestLocation()
    }
    
    @objc private func didTapMap() {
        let storyboard = UIStoryboard(name:"SharedStoryboard",bundle:nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            mapVC.delegate = self
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let error = error { return }
            
            if let placemark = placemarks?.first {
                let city = placemark.locality ?? ""
                let country = placemark.country ?? ""
                var address = ""
                if !city.isEmpty { address += city + ", " }
                address += country
                
                DispatchQueue.main.async {
                    self.updateLocationSelection(address)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Error: \(error.localizedDescription)")
    }
    
    private func updateLocationSelection(_ name: String) {
        locationSearchBar.text = name
        suggestionsTableView.isHidden = true
        locationSearchBar.resignFirstResponder()
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardHandling() {
        // Basic keyboard handling if needed
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
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
        
        let alert = UIAlertController(title: "Delete Bird", message: "Delete this bird from watchlist?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.viewModel?.deleteBird(birdToDelete, from: id)
            self?.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
    }
    
    @objc func didTapSave() {
        // Create or Update Bird
        // For Unobserved, usually we are just setting ranges.
        // But if editing, we might change name too.
        
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
        
        if let vm = viewModel, let wId = watchlistId {
            vm.updateBird(updatedBird, watchlistId: wId)
            navigationController?.popViewController(animated: true)
        } else {
            // New Bird Logic
            coordinator?.saveBirdDetails(bird: updatedBird)
        }
    }
    
    func configure(with bird: Bird) {
        self.navigationItem.title = "Edit Species"
        
        nameTextField.text = bird.name
        
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
        
        if let firstDate = bird.date.first { startDatePicker.date = firstDate }
        if let lastDate = bird.date.last { endDatePicker.date = lastDate }
        
        if let locationName = bird.location.first {
            locationSearchBar.text = locationName
        }
        
        notesTextView.text = bird.notes ?? "Add notes..."
    }
    
    func setupStyling() {
        view.backgroundColor = .systemGray6
        birdImageView.layer.cornerRadius = 24
        birdImageView.clipsToBounds = true
        
        styleCard(detailsCardView)
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
extension UnobservedDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
        cell.backgroundColor = .white
        cell.textLabel?.textColor = .black
        let result = locationResults[indexPath.row]
        cell.textLabel?.text = result.title + " " + result.subtitle
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let result = locationResults[indexPath.row]
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        search.start { [weak self] (response, error) in
            guard let self = self, let response = response else { return }
            let name = response.mapItems.first?.name ?? result.title
            self.updateLocationSelection(name)
        }
    }
}

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
        updateSuggestionsLayout()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        suggestionsTableView.isHidden = true
    }
}

extension UnobservedDetailViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        locationResults = completer.results
        suggestionsTableView.isHidden = locationResults.isEmpty
        suggestionsTableView.reloadData()
        updateSuggestionsLayout()
    }
}

extension UnobservedDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(_ locationName: String) {
        updateLocationSelection(locationName)
    }
}