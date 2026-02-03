//
//  HistoryCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 21/01/26.
//

import UIKit
import SwiftData

class HistoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var historyImageView: UIImageView!
    @IBOutlet weak var specieNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 16
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        historyImageView.image = nil
        historyImageView.tintColor = nil
        historyImageView.contentMode = .scaleAspectFill
        historyImageView.layer.cornerRadius = 0

        specieNameLabel.text = nil
        specieNameLabel.textAlignment = .left
        specieNameLabel.textColor = .label

        dateLabel.text = nil
        dateLabel.textAlignment = .left
        dateLabel.textColor = .secondaryLabel

        contentView.backgroundColor = .white
        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = UIColor.clear.cgColor
    }
    
    func showEmptyState() {
        historyImageView.image = UIImage(systemName: "clock.arrow.circlepath")
        historyImageView.tintColor = .systemGray3
        historyImageView.contentMode = .scaleAspectFit
        historyImageView.layer.cornerRadius = 0

        specieNameLabel.text = "No history yet"
        specieNameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        specieNameLabel.textAlignment = .center
        specieNameLabel.textColor = .secondaryLabel

        dateLabel.text = "Start identifying birds"
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textAlignment = .center
        dateLabel.textColor = .tertiaryLabel

        layer.shadowOpacity = 0
    }

    override var isSelected: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                if self.isSelected {
                    self.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
                    self.contentView.layer.borderWidth = 1.5
                    self.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                } else {
                    self.contentView.backgroundColor = .white
                    self.contentView.layer.borderWidth = 0
                    self.contentView.layer.borderColor = UIColor.clear.cgColor
                }
            }
        }
    }


    func configureCell(historyItem: IdentificationSession) {
        contentView.backgroundColor = .white
        layer.shadowOpacity = 0.12

       
        if let bird = historyItem.result?.bird {
            specieNameLabel.text = bird.commonName
            
            if let image = UIImage(named: bird.staticImageName) {
                historyImageView.image = image
            } else {
                historyImageView.image = UIImage(systemName: "bird.fill") // Fallback
            }
        } else {
            // Handle cases where session exists but no bird is assigned (e.g. In Progress)
            specieNameLabel.text = "Unknown Bird"
            historyImageView.image = UIImage(systemName: "questionmark.circle")
        }

        historyImageView.contentMode = .scaleAspectFill
        historyImageView.layer.cornerRadius = 10
        
      
        dateLabel.text = formatDate(historyItem.observationDate)
    }

   
    private func formatDate(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM"
        return outputFormatter.string(from: date)
    }
}
