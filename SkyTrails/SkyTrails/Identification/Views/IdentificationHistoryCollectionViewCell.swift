//
//  historyCollectionViewCell.swift
//  SkyTrails
//
//  Created by Disha Jain on 26/11/25.
//

import UIKit

class IdentificationHistoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var historyImageView: UIImageView!
    @IBOutlet weak var specieNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

    func configureCell(historyItem: History) {
        historyImageView.image = UIImage(named: historyItem.imageView)
        historyImageView.clipsToBounds = true
        historyImageView.layer.cornerRadius = 10.0
        specieNameLabel.text = historyItem.specieName
        
        func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
        dateLabel.text = formatDate(historyItem.date)
    }
}

