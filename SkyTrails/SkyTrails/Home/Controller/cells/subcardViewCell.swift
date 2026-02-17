//
//  subcardViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 17/02/26.
//

import UIKit

class subcardViewCell: UICollectionViewCell {
    
    static let identifier = "subcardViewCell"
    
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var birdNameLabel: UILabel!
    @IBOutlet weak var statusBadgeContainer: UIView!
    @IBOutlet weak var badgeIconImageView: UIImageView!
    @IBOutlet weak var badgeTitleLabel: UILabel!
    @IBOutlet weak var badgeSubtitleLabel: UILabel!
    @IBOutlet weak var sightabilityIconLabel: UILabel!
    @IBOutlet weak var sightabilityTextLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }
    
    private func setupAppearance() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        
        birdImageView.layer.cornerRadius = 8
        birdImageView.contentMode = .scaleAspectFill
        
        statusBadgeContainer.layer.cornerRadius = 6
        
        // Border for the cell to distinguish it from the parent card
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray6.cgColor
    }
    
    func configure(with birdData: BirdSpeciesDisplay) {
        print("🐦 [PredictionDebug] subcardViewCell configure: \(birdData.birdName)")
        birdNameLabel.text = birdData.birdName
        
        if let image = UIImage(named: birdData.birdImageName) {
            birdImageView.image = image
            print("🐦 [PredictionDebug]   ✅ Image loaded: \(birdData.birdImageName)")
        } else {
            birdImageView.image = UIImage(systemName: "bird.fill")
            birdImageView.tintColor = .systemGray4
            print("⚠️ [PredictionDebug]   ❌ Image NOT FOUND: \(birdData.birdImageName)")
        }
        
        // Badge
        badgeTitleLabel.text = birdData.statusBadge.title
        badgeSubtitleLabel.text = birdData.statusBadge.subtitle
        
        if let badgeColor = UIColor(named: birdData.statusBadge.backgroundColorName) {
            statusBadgeContainer.backgroundColor = badgeColor
            print("🐦 [PredictionDebug]   ✅ Badge color loaded: \(birdData.statusBadge.backgroundColorName)")
        } else {
            statusBadgeContainer.backgroundColor = .systemPink.withAlphaComponent(0.1)
            print("⚠️ [PredictionDebug]   ❌ Badge color NOT FOUND: \(birdData.statusBadge.backgroundColorName)")
        }
        
        if !birdData.statusBadge.iconName.isEmpty {
            badgeIconImageView.image = UIImage(systemName: birdData.statusBadge.iconName)
        }
        
        // Sightability
        sightabilityTextLabel.text = "Sightability - \(birdData.sightabilityPercent)%"
        print("🐦 [PredictionDebug]   Sightability set to \(birdData.sightabilityPercent)%")
    }
}
