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
        setupPicker()
    }
    private func setupPicker() {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
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

