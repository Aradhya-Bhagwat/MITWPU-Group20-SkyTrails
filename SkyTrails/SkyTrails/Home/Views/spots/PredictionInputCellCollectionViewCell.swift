//
//  PredictionInputCellCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit

class PredictionInputCellCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "PredictionInputCellCollectionViewCell"
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    
    @IBOutlet weak var areaTextField: UITextField!
    @IBOutlet weak var areaStepper: UIStepper!
    
    // MARK: - Date Pickers
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    
    // MARK: - Closures
    var onDelete: (() -> Void)?
    var onSearchTap: (() -> Void)?
    var onAreaChange: ((Int) -> Void)?
    
    // Updated closures to pass the new Date value
    var onStartDateChange: ((Date) -> Void)?
    var onEndDateChange: ((Date) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        setupStyle()
        setupStepper()
        setupTextField()
        setupDatePickers()
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
        
        styleButton(searchButton)
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
    
    private func styleButton(_ button: UIButton) {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
        config.baseBackgroundColor = .systemGray6
        config.baseForegroundColor = .label
        config.titleAlignment = .leading

        button.configuration = config
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
    }
    
    private func setupStepper() {
        areaStepper.minimumValue = 2
        areaStepper.maximumValue = 24
        areaStepper.stepValue = 1
        areaStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
    }
    
    private func setupTextField() {
        areaTextField.keyboardType = .numberPad
        areaTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingDidEnd)
        areaTextField.borderStyle = .none
        areaTextField.layer.cornerRadius = 8
        areaTextField.backgroundColor = .systemGray6
        areaTextField.layer.borderWidth = 1
        areaTextField.layer.borderColor = UIColor.systemGray5.cgColor
    }

    // MARK: - Actions
    
    @IBAction func didTapDelete(_ sender: Any) {
        onDelete?()
    }
    
    @IBAction func didTapSearch(_ sender: Any) {
        onSearchTap?()
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
        areaTextField.text = "\(value) km²"
        onAreaChange?(value)
    }
    
    @objc func textFieldChanged(_ sender: UITextField) {
        let text = sender.text?.replacingOccurrences(of: " km²", with: "") ?? ""
        if let value = Int(text) {
            let clampedValue = min(24, max(2, value))
            areaStepper.value = Double(clampedValue)
            areaTextField.text = "\(clampedValue) km²"
            onAreaChange?(clampedValue)
        }
    }

    // MARK: - Configuration
    func configure(data: PredictionInputData, index: Int) {
        titleLabel.text = "Input \(index + 1)"
        
        // 1. Location Button
        if let location = data.locationName {
            searchButton.setTitle(location, for: .normal)
            searchButton.setTitleColor(.label, for: .normal)
        } else {
            searchButton.setTitle("Search Location", for: .normal)
            searchButton.setTitleColor(.secondaryLabel, for: .normal)
        }
        
        // 2. Date Pickers
        // DatePickers cannot be nil, so we default to Date() (now) if data is nil
        startDatePicker.date = data.startDate ?? Date()
        endDatePicker.date = data.endDate ?? Date()
        
        // 3. Area
        areaStepper.value = Double(data.areaValue)
        areaTextField.text = "\(data.areaValue) km²"
        
        // 4. Delete Logic
        deleteButton.isHidden = (index == 0)
    }
}
