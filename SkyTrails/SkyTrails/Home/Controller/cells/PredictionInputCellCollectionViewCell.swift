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
    @IBOutlet weak var areaLabel: UILabel!
    @IBOutlet weak var areaStepper: UIStepper!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    
    var onDelete: (() -> Void)?
    var onLocationSelected: ((String, Double, Double) -> Void)?
    var onAreaChange: ((Int) -> Void)?
    var onSearchTap: (() -> Void)?
    var onStartDateChange: ((Date) -> Void)?
    var onEndDateChange: ((Date) -> Void)?
    
    private let locationManager = CLLocationManager()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
        
        setupStyle()
        setupStepper()
        setupDatePickers()
        setupSearch()
        setupLocationServices()
        applySemanticAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if traitCollection.userInterfaceStyle != .dark {
            containerView.layer.shadowPath = UIBezierPath(roundedRect: containerView.bounds, cornerRadius: 16).cgPath
        }
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }
    
    private func setupStyle() {
       
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = false
        
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Search Location"
        
    }
    
    private func setupSearch() {
        searchBar.delegate = self
    }
    
    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupDatePickers() {
      
        startDatePicker.datePickerMode = .date
        startDatePicker.preferredDatePickerStyle = .compact
        startDatePicker.addTarget(self, action: #selector(startDateChanged(_:)), for: .valueChanged)
        
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

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = cardColor

        [titleLabel, areaLabel].forEach { $0?.textColor = .label }
        searchBar.barStyle = .default
        searchBar.searchBarStyle = .minimal
        searchBar.searchTextField.textColor = .label
        searchBar.searchTextField.backgroundColor = isDarkMode ? .tertiarySystemBackground : .systemBackground
        searchBar.searchTextField.layer.borderWidth = isDarkMode ? 0 : 1
        searchBar.searchTextField.layer.borderColor = isDarkMode ? UIColor.clear.cgColor : UIColor.systemGray4.cgColor
        searchBar.searchTextField.layer.cornerRadius = 10
        searchBar.searchTextField.clipsToBounds = true
        startDatePicker.tintColor = .systemBlue
        endDatePicker.tintColor = .systemBlue
        startDatePicker.overrideUserInterfaceStyle = .unspecified
        endDatePicker.overrideUserInterfaceStyle = .unspecified
        areaStepper.tintColor = .systemBlue

        if isDarkMode {
            containerView.layer.shadowOpacity = 0
            containerView.layer.shadowRadius = 0
            containerView.layer.shadowOffset = .zero
            containerView.layer.shadowPath = nil
        } else {
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOpacity = 0.08
            containerView.layer.shadowOffset = CGSize(width: 0, height: 3)
            containerView.layer.shadowRadius = 6
            containerView.layer.shadowPath = UIBezierPath(roundedRect: containerView.bounds, cornerRadius: 16).cgPath
        }
    }

    @IBAction func didTapDelete(_ sender: Any) {
        onDelete?()
    }
    
    @objc func startDateChanged(_ sender: UIDatePicker) {
        onStartDateChange?(sender.date)
    }
    
    @objc func endDateChanged(_ sender: UIDatePicker) {
        onEndDateChange?(sender.date)
    }
    
    @objc func stepperChanged(_ sender: UIStepper) {
        let value = Int(sender.value)
        areaLabel.text = "\(value) km"
        onAreaChange?(value)
    }
    
    func configure(data: PredictionInputData, index: Int) {
        titleLabel.text = "Input \(index + 1)"

        if let location = data.locationName {
            searchBar.text = location
        } else {
            searchBar.text = ""
        }
        
        startDatePicker.date = data.startDate ?? Date()
        endDatePicker.date = data.endDate ?? Date()
        
        areaStepper.value = Double(data.areaValue)
        areaLabel.text = "\(data.areaValue) km"
        
        deleteButton.isHidden = (index == 0)
    }
    
    private func fetchCurrentLocation() {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location Access Denied")
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    private func updateSelection(name: String, lat: Double, lon: Double) {
        searchBar.text = name
        searchBar.resignFirstResponder()
        onLocationSelected?(name, lat, lon)
    }
}

extension PredictionInputCellCollectionViewCell: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        onSearchTap?()
        return false
    }
}

extension PredictionInputCellCollectionViewCell: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 100, longitudinalMeters: 100)
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] response, error in
            guard let self = self else { return }

            let name = response?.mapItems.first?.name ?? "Current Location"
            
            self.updateSelection(
                name: name,
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude
            )
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
