//
//  historyCollectionViewCell.swift
//  SkyTrails
//
//  Created by Disha Jain on 26/11/25.
//

import UIKit

class historyCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var historyimageView: UIImageView!
    @IBOutlet weak var SpecieNameLabel: UILabel!
    @IBOutlet weak var DateLabel: UILabel!
    
    func configureCell(historyItem: History) {
        historyimageView.image = UIImage(named: historyItem.imageView)
        historyimageView.clipsToBounds = true
        historyimageView.layer.cornerRadius = 10.0
        SpecieNameLabel.text = historyItem.specieName
        
        func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"   // Example: 23 Oct
            return formatter.string(from: date)
        }
        DateLabel.text = formatDate(historyItem.date)
    }
}

