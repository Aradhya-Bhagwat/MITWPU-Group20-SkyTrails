	//
	//  EditWatchlistDetailViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 10/12/25.
	//

import UIKit
import CoreLocation

	// Local helper struct for the UI
struct Participant {
	let name: String
	let imageName: String
}

class EditWatchlistDetailViewController: UIViewController, CLLocationManagerDelegate {
	
		// MARK: - Outlets
	@IBOutlet weak var titleTextField: UITextField!
	@IBOutlet weak var locationTextField: UITextField!
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
	}
	
	private func initializeParticipants() {
			// If editing, map existing images to names (Mock logic since model only has images)
		if let shared = sharedWatchlistToEdit {
			self.participants = shared.userImages.enumerated().map { (index, img) in
				if index == 0 { return Participant(name: "You", imageName: img) }
					// Assign mock names to existing data if needed, or generic
				return Participant(name: "Bird Enthusiast \(index)", imageName: img)
			}
		} else {
				// New Watchlist default
			self.participants = [Participant(name: "You", imageName: "person.circle.fill")]
		}
	}
	
	private func setupLocationManager() {
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.requestWhenInUseAuthorization()
	}
	
		// MARK: - Location Logic
	@objc private func didTapCurrentLocation() {
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
	
	private func populateDataForEdit() {
		if let watchlist = watchlistToEdit {
			self.title = "Edit Watchlist"
			titleTextField.text = watchlist.title
			locationTextField.text = watchlist.location
			startDatePicker.date = watchlist.startDate
			endDatePicker.date = watchlist.endDate
		} else if let shared = sharedWatchlistToEdit {
			self.title = "Edit Shared Watchlist"
			titleTextField.text = shared.title
			locationTextField.text = shared.location
		}
	}
	
	private func setupUI() {
		if watchlistToEdit == nil && sharedWatchlistToEdit == nil {
			self.title = "New Watchlist"
		}
		view.backgroundColor = .systemGray6
		
			// Add location button to text field
		let locationButton = UIButton(type: .system)
		locationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
		locationButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
		locationButton.addTarget(self, action: #selector(didTapCurrentLocation), for: .touchUpInside)
		
		locationTextField.rightView = locationButton
		locationTextField.rightViewMode = .always
		
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
			// Clear existing subviews
		view.subviews.forEach { $0.removeFromSuperview() }
		
			// 1. Header Label
		let titleLabel = UILabel()
		titleLabel.text = "Participants"
		titleLabel.textColor = .secondaryLabel
		titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		
			// 2. TableView Setup
		participantsTableView.delegate = self
		participantsTableView.dataSource = self
		participantsTableView.translatesAutoresizingMaskIntoConstraints = false
		
			// 3. Invite Button
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
			// Header
			titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
			titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			
			// TableView (Fixed height for prototype loop)
			participantsTableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
			participantsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
			participantsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
			participantsTableView.heightAnchor.constraint(equalToConstant: 120), // Show ~2.5 rows
			
			// Invite Button
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
				// Simulate adding participants on completion
			if completed {
				self?.simulateAddingParticipants()
			}
		}
		
		present(activityVC, animated: true)
	}
	
	private func simulateAddingParticipants() {
			// Mock: Check if already added to avoid duplicates in demo
		if participants.contains(where: { $0.name == "Aradhya" }) { return }
		
		let p1 = Participant(name: "Aradhya", imageName: "person.crop.circle")
		let p2 = Participant(name: "Disha", imageName: "person.crop.circle.fill")
		
		participants.append(contentsOf: [p1, p2])
		participantsTableView.reloadData()
		
			// Feedback
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
		
		let location = locationTextField.text ?? "Unknown"
		let startDate = startDatePicker.date
		let endDate = endDatePicker.date
		
			// Extract raw image strings from participants
		let finalUserImages = participants.map { $0.imageName }
		
			// UPDATE Existing
		if let watchlist = watchlistToEdit {
			viewModel?.updateWatchlist(id: watchlist.id, title: title, location: location, startDate: startDate, endDate: endDate)
			navigationController?.popViewController(animated: true)
			return
		}
		
		if let shared = sharedWatchlistToEdit {
			let dr = formatDateRange(start: startDate, end: endDate)
			
				// Sync participants to ViewModel
			if let index = viewModel?.sharedWatchlists.firstIndex(where: { $0.id == shared.id }) {
				viewModel?.sharedWatchlists[index].userImages = finalUserImages
			}
			
			viewModel?.updateSharedWatchlist(id: shared.id, title: title, location: location, dateRange: dr)
			navigationController?.popViewController(animated: true)
			return
		}
		
			// CREATE New
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
				userImages: finalUserImages // Save the participants
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

// MARK: - TableView Delegate & DataSource
extension EditWatchlistDetailViewController: UITableViewDelegate, UITableViewDataSource {
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return participants.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ParticipantCell", for: indexPath)
		let participant = participants[indexPath.row]
		
			// Configure Text
		cell.textLabel?.text = participant.name
		cell.textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
		
			// Configure Image
			// Use SF Symbols or Assets
		if let image = UIImage(systemName: participant.imageName) {
			cell.imageView?.image = image
		} else {
				// Fallback for non-system images if you use assets
			cell.imageView?.image = UIImage(systemName: "person.circle")
		}
		cell.imageView?.tintColor = .systemBlue
		cell.selectionStyle = .none
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 44
	}
}
