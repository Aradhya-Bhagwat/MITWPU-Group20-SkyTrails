//
//  PredictionInputCellCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit
import MapKit
import CoreLocation

class PredictionInputCellCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "PredictionInputCellCollectionViewCell"
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    // @IBOutlet weak var suggestionsTableView: UITableView! // Removed
    
    @IBOutlet weak var areaLabel: UILabel!
    @IBOutlet weak var areaStepper: UIStepper!
    
    // MARK: - Date Pickers
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    
    // MARK: - Closures
    var onDelete: (() -> Void)?
    var onLocationSelected: ((String, Double, Double) -> Void)?
    var onAreaChange: ((Int) -> Void)?
    var onSearchTap: (() -> Void)? // New closure for search navigation
    
    // Updated closures to pass the new Date value
    var onStartDateChange: ((Date) -> Void)?
    var onEndDateChange: ((Date) -> Void)?
    
    // Search State
    // private var searchCompleter = MKLocalSearchCompleter() // Removed
    // private var searchResults: [MKLocalSearchCompletion] = [] // Removed
    private let locationManager = CLLocationManager()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setupStyle()
        setupStepper()
        setupDatePickers()
        setupSearch()
        setupLocationServices()
    }
    
    private func setupStyle() {
        // Container Card Style
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Search Location"
        
        // suggestionsTableView.layer.cornerRadius = 8 // Removed
        // suggestionsTableView.layer.borderWidth = 1 // Removed
        // suggestionsTableView.layer.borderColor = UIColor.systemGray5.cgColor // Removed
        // suggestionsTableView.isHidden = true // Removed
    }
    
    private func setupSearch() {
        searchBar.delegate = self
        // searchCompleter.delegate = self // Removed
        // searchCompleter.resultTypes = .pointOfInterest // Removed
        
        // suggestionsTableView.delegate = self // Removed
        // suggestionsTableView.dataSource = self // Removed
        // suggestionsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell") // Removed
    }
    
    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupDatePickers() {
        // Configure Start Date Picker
        startDatePicker.datePickerMode = .date
        startDatePicker.preferredDatePickerStyle = .compact
        startDatePicker.addTarget(self, action: #selector(startDateChanged(_:)), for: .valueChanged)
        
        // Configure End Date Picker
        endDatePicker.datePickerMode = .date
        endDatePicker.preferredDatePickerStyle = .compact
        endDatePicker.addTarget(self, action: #selector(endDateChanged(_:)), for: .valueChanged)
    }

    
    private func setupStepper() {
        areaStepper.minimumValue = 2
        areaStepper.maximumValue = 24
        areaStepper.stepValue = 1
        areaStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
    }

    // MARK: - Actions
    
    @IBAction func didTapDelete(_ sender: Any) {
        onDelete?()
    }
    
    // MARK: - Date Actions
    
    @objc func startDateChanged(_ sender: UIDatePicker) {
        onStartDateChange?(sender.date)
    }
    
    @objc func endDateChanged(_ sender: UIDatePicker) {
        onEndDateChange?(sender.date)
    }
    
    // MARK: - Area Actions
    
    @objc func stepperChanged(_ sender: UIStepper) {
        let value = Int(sender.value)
        areaLabel.text = "\(value) km"
        onAreaChange?(value)
    }

    // MARK: - Configuration
    func configure(data: PredictionInputData, index: Int) {
        titleLabel.text = "Input \(index + 1)"
        
        // 1. Location Search Bar
        if let location = data.locationName {
            searchBar.text = location
        } else {
            searchBar.text = ""
        }
        
        // 2. Date Pickers
        startDatePicker.date = data.startDate ?? Date()
        endDatePicker.date = data.endDate ?? Date()
        
        // 3. Area
        areaStepper.value = Double(data.areaValue)
        areaLabel.text = "\(data.areaValue) km"
        
        // 4. Delete Logic
        deleteButton.isHidden = (index == 0)
    }
    
    // MARK: - Helper Methods
    private func fetchCurrentLocation() {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location Access Denied") // Handle properly in a real app
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    private func updateSelection(name: String, lat: Double, lon: Double) {
        searchBar.text = name
        // suggestionsTableView.isHidden = true // Removed
        searchBar.resignFirstResponder()
        onLocationSelected?(name, lat, lon)
    }
}

// MARK: - UISearchBarDelegate
extension PredictionInputCellCollectionViewCell: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Intercept tap and trigger navigation
        onSearchTap?()
        return false // Prevent keyboard from showing
    }
}

// MARK: - CLLocationManagerDelegate
extension PredictionInputCellCollectionViewCell: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            let name = placemarks?.first?.name ?? "Current Location"
            self.updateSelection(name: name, lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Error: \(error.localizedDescription)")
    }
}
