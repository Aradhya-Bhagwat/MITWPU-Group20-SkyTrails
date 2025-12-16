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
        @IBOutlet weak var startDateButton: UIButton!
        @IBOutlet weak var endDateButton: UIButton!
        @IBOutlet weak var areaTextField: UITextField!
        @IBOutlet weak var areaStepper: UIStepper!
    
    var onDelete: (() -> Void)?
        var onSearchTap: (() -> Void)?
        var onAreaChange: ((Int) -> Void)?
        var onStartDateTap: (() -> Void)?
        var onEndDateTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        setupStyle()
        setupStepper()
        setupTextField()
        setupDateButtons()
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
        
        private func setupDateButtons() {
            styleButton(startDateButton)
            styleButton(endDateButton)
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
        
        @IBAction func didTapStartDate(_ sender: Any) {
            onStartDateTap?()
        }
        
        @IBAction func didTapEndDate(_ sender: Any) {
            onEndDateTap?()
        }
        
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
            
            if let location = data.locationName {
                searchButton.setTitle(location, for: .normal)
                searchButton.setTitleColor(.label, for: .normal)
            } else {
                searchButton.setTitle("Search Location", for: .normal)
                searchButton.setTitleColor(.secondaryLabel, for: .normal)
            }
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium // e.g. "Oct 12, 2025"
            formatter.timeStyle = .none
            
            if let start = data.startDate {
                startDateButton.setTitle(formatter.string(from: start), for: .normal)
                startDateButton.setTitleColor(.label, for: .normal)
            } else {
                startDateButton.setTitle("Start Date", for: .normal)
                startDateButton.setTitleColor(.secondaryLabel, for: .normal)
            }
            
            if let end = data.endDate {
                endDateButton.setTitle(formatter.string(from: end), for: .normal)
                endDateButton.setTitleColor(.label, for: .normal)
            } else {
                endDateButton.setTitle("End Date", for: .normal)
                endDateButton.setTitleColor(.secondaryLabel, for: .normal)
            }
            
            // 3. Area
            areaStepper.value = Double(data.areaValue)
            areaTextField.text = "\(data.areaValue) km²"
            
            // 4. Delete Logic (Hide delete if it's the only card)
            deleteButton.isHidden = (index == 0) // Optional: prevent deleting the last card
        }

}
