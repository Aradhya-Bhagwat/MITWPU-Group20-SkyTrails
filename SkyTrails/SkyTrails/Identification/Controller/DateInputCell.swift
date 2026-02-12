//
//  DateInputCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//
import UIKit

protocol DateInputCellDelegate: AnyObject {
    func dateInputCell(_ cell: DateInputCell, didPick date: Date)
}

class DateInputCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var datePicker: UIDatePicker!
    weak var delegate: DateInputCellDelegate?
    
   
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
        setupPicker()
        applySemanticAppearance()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }

    private func setupPicker() {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    }

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cellColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        let pickerColor: UIColor = isDarkMode ? .tertiarySystemBackground : .secondarySystemBackground

        selectionStyle = .none
        backgroundColor = cellColor
        contentView.backgroundColor = cellColor
        for subview in contentView.subviews {
            subview.backgroundColor = cellColor
        }

        titleLabel.textColor = .label
        datePicker.tintColor = .systemBlue
        datePicker.backgroundColor = pickerColor
        datePicker.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
        datePicker.layer.cornerRadius = 8
        datePicker.layer.masksToBounds = true
    }
    func configure(withTitle title: String, date: Date?) {
        titleLabel.text = title
        if let d = date {
            datePicker.date = d
        }
    }
    @objc private func dateChanged() {
        delegate?.dateInputCell(self, didPick: datePicker.date)
    }
}
