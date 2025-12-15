//
//  EditWatchlistDetailViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit
import CoreLocation
import MapKit

// Local helper struct for the UI
struct Participant {
    let name: String
    let imageName: String
}

class EditWatchlistDetailViewController: UIViewController, CLLocationManagerDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var locationSearchBar: UISearchBar!
    @IBOutlet weak var locationOptionsContainer: UIView!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    @IBOutlet weak var inviteContactsView: UIView!
    
    // MARK: - Properties
    var viewModel: WatchlistViewModel?
    var watchlistType: WatchlistType = .custom
    weak var coordinator: WatchlistCoordinator?
    
    // Edit Mode Properties
    var watchlistToEdit: Watchlist?
    var sharedWatchlistToEdit: SharedWatchlist?
    
    private let locationManager = CLLocationManager()
    
    // Autocomplete
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []
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
    
    // Internal State
    private var participants: [Participant] = []
    private var participantsTableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "ParticipantCell")
        tv.separatorStyle = .singleLine
        tv.backgroundColor = .clear
        return tv
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureViewBasedOnType()
        
        // Initialize Data
        initializeParticipants()
        populateDataForEdit()
        
        // Add Save Button
        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
        navigationItem.rightBarButtonItem = saveButton
        
        setupLocationManager()
        setupSearch()
        setupLocationOptionsInteractions()
    }
    
    private func initializeParticipants() {
        if let shared = sharedWatchlistToEdit {
            self.participants = shared.userImages.enumerated().map { (index, img) in
                if index == 0 { return Participant(name: "You", imageName: img) }
                return Participant(name: "Bird Enthusiast \(index)", imageName: img)
            }
        } else {
            self.participants = [Participant(name: "You", imageName: "person.circle.fill")]
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupSearch() {
        searchCompleter.delegate = self
        locationSearchBar.delegate = self
        
        // Add suggestions table to the view hierarchy
        // We add it to the main view to float above everything
        view.addSubview(suggestionsTableView)
    }
    
    private func setupLocationOptionsInteractions() {
        guard let container = locationOptionsContainer else { return }
        
        // Assuming the structure: StackView -> [CurrentLocationStack, Separator, MapStack]
        // We will try to find the clickable views.
        // Based on storyboard structure, the container has one subview (Main Stack).
        // That Main Stack has 3 subviews.
        
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
        
        // Convert search bar frame to main view coordinates
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
    
    // MARK: - Location Logic
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
                    self.updateLocationSelection(address)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }
    
    private func updateLocationSelection(_ name: String) {
        locationSearchBar.text = name
        suggestionsTableView.isHidden = true
        locationSearchBar.resignFirstResponder()
    }
    
    private func populateDataForEdit() {
        if let watchlist = watchlistToEdit {
            self.title = "Edit Watchlist"
            titleTextField.text = watchlist.title
            locationSearchBar.text = watchlist.location
            startDatePicker.date = watchlist.startDate
            endDatePicker.date = watchlist.endDate
        } else if let shared = sharedWatchlistToEdit {
            self.title = "Edit Shared Watchlist"
            titleTextField.text = shared.title
            locationSearchBar.text = shared.location
        }
    }
    
    private func setupUI() {
        if watchlistToEdit == nil && sharedWatchlistToEdit == nil {
            self.title = "New Watchlist"
        }
        view.backgroundColor = .systemGray6
        
        // InviteContactsView Styling
        if let inviteView = inviteContactsView {
            inviteView.layer.cornerRadius = 12
            inviteView.backgroundColor = .white
            inviteView.layer.shadowColor = UIColor.black.cgColor
            inviteView.layer.shadowOpacity = 0.05
            inviteView.layer.shadowOffset = CGSize(width: 0, height: 2)
            inviteView.layer.shadowRadius = 8
            
            setupInviteContent(in: inviteView)
        }
    }
    
    private func setupInviteContent(in view: UIView) {
        view.subviews.forEach { $0.removeFromSuperview() }
        
        let titleLabel = UILabel()
        titleLabel.text = "Participants"
        titleLabel.textColor = .secondaryLabel
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        participantsTableView.delegate = self
        participantsTableView.dataSource = self
        participantsTableView.translatesAutoresizingMaskIntoConstraints = false
        
        var config = UIButton.Configuration.tinted()
        config.title = "Invite Friends"
        config.image = UIImage(systemName: "square.and.arrow.up")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        
        let inviteButton = UIButton(configuration: config)
        inviteButton.translatesAutoresizingMaskIntoConstraints = false
        inviteButton.addTarget(self, action: #selector(didTapInvite), for: .touchUpInside)
        
        view.addSubview(titleLabel)
        view.addSubview(participantsTableView)
        view.addSubview(inviteButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            participantsTableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            participantsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            participantsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            participantsTableView.heightAnchor.constraint(equalToConstant: 120),
            
            inviteButton.topAnchor.constraint(equalTo: participantsTableView.bottomAnchor, constant: 12),
            inviteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inviteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            inviteButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            inviteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func configureViewBasedOnType() {
        switch watchlistType {
            case .custom, .myWatchlist:
                inviteContactsView.isHidden = true
            case .shared:
                inviteContactsView.isHidden = false
        }
    }
    
    // MARK: - Invite Logic
    @objc private func didTapInvite() {
        let titleToShare = titleTextField.text ?? "New Watchlist"
        let shareText = "Hey! Join my Bird Watchlist: \(titleToShare) on SkyTrails!"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = inviteContactsView
            popover.sourceRect = inviteContactsView.bounds
        }
        
        activityVC.completionWithItemsHandler = { [weak self] (activityType, completed, returnedItems, error) in
            if completed {
                self?.simulateAddingParticipants()
            }
        }
        
        present(activityVC, animated: true)
    }
    
    private func simulateAddingParticipants() {
        if participants.contains(where: { $0.name == "Aradhya" }) { return }
        
        let p1 = Participant(name: "Aradhya", imageName: "person.crop.circle")
        let p2 = Participant(name: "Disha", imageName: "person.crop.circle.fill")
        
        participants.append(contentsOf: [p1, p2])
        participantsTableView.reloadData()
        
        let alert = UIAlertController(title: "Invites Sent", message: "Aradhya and Disha have been added.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Save Logic
    @objc private func didTapSave() {
        guard let title = titleTextField.text, !title.isEmpty else {
            let alert = UIAlertController(title: "Missing Info", message: "Please enter a title.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let location = locationSearchBar.text ?? "Unknown"
        let startDate = startDatePicker.date
        let endDate = endDatePicker.date
        
        let finalUserImages = participants.map { $0.imageName }
        
        if let watchlist = watchlistToEdit {
            viewModel?.updateWatchlist(id: watchlist.id, title: title, location: location, startDate: startDate, endDate: endDate)
            navigationController?.popViewController(animated: true)
            return
        }
        
        if let shared = sharedWatchlistToEdit {
            let dr = formatDateRange(start: startDate, end: endDate)
            if let index = viewModel?.sharedWatchlists.firstIndex(where: { $0.id == shared.id }) {
                viewModel?.sharedWatchlists[index].userImages = finalUserImages
            }
            viewModel?.updateSharedWatchlist(id: shared.id, title: title, location: location, dateRange: dr)
            navigationController?.popViewController(animated: true)
            return
        }
        
        if watchlistType == .custom {
            let newWatchlist = Watchlist(
                title: title,
                location: location,
                startDate: startDate,
                endDate: endDate,
                observedBirds: [],
                toObserveBirds: []
            )
            viewModel?.addWatchlist(newWatchlist)
            
        } else if watchlistType == .shared {
            let newShared = SharedWatchlist(
                title: title,
                location: location,
                dateRange: formatDateRange(start: startDate, end: endDate),
                mainImageName: "bird_placeholder",
                stats: SharedWatchlistStats(greenValue: 0, blueValue: 0),
                userImages: finalUserImages
            )
            viewModel?.addSharedWatchlist(newShared)
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Delegates
extension EditWatchlistDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == participantsTableView {
            return participants.count
        } else {
            return searchResults.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == participantsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ParticipantCell", for: indexPath)
            let participant = participants[indexPath.row]
            cell.textLabel?.text = participant.name
            cell.textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
            if let image = UIImage(systemName: participant.imageName) {
                cell.imageView?.image = image
            } else {
                cell.imageView?.image = UIImage(systemName: "person.circle")
            }
            cell.imageView?.tintColor = .systemBlue
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
            cell.backgroundColor = .white
            cell.textLabel?.textColor = .black
            let item = searchResults[indexPath.row]
            cell.textLabel?.text = item.title + " " + item.subtitle
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == suggestionsTableView {
            let item = searchResults[indexPath.row]
            let request = MKLocalSearch.Request(completion: item)
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, _ in
                guard let self = self, let place = response?.mapItems.first else { return }
                let name = place.name ?? item.title
                self.updateLocationSelection(name)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}

extension EditWatchlistDetailViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults = []
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

extension EditWatchlistDetailViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
        suggestionsTableView.isHidden = searchResults.isEmpty
        suggestionsTableView.reloadData()
        updateSuggestionsLayout()
    }
}

extension EditWatchlistDetailViewController: MapSelectionDelegate {
    func didSelectMapLocation(_ locationName: String) {
        updateLocationSelection(locationName)
    }
}