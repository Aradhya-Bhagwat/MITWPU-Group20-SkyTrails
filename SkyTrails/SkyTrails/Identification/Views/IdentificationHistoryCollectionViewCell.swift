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
        
        func formatDate(_ dateString: String) -> String {

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "d MMM"

            if let date = formatter.date(from: dateString) {
                return outputFormatter.string(from: date)
            } else {
                return dateString   
            }
        }

        dateLabel.text = formatDate(historyItem.date)
    }
}

