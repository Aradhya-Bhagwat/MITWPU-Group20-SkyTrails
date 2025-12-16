//
//  SpotsToVisitCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class SpotsToVisitCollectionViewCell: UICollectionViewCell {

    static let identifier = "SpotsToVisitCollectionViewCell"

    @IBOutlet weak var locationImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var containerView: UIView! // If you added a wrapper view

    override func awakeFromNib() {
        super.awakeFromNib()
        setupStyle()
    }

    private func setupStyle() {
        
        self.backgroundColor = .clear
        
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.15  // Adjust for darkness (0.1 to 0.2 is good)
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4) // Shadow moves down slightly
        contentView.layer.shadowRadius = 8 // Softness of the shadow
        contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        
        // Round Corners
        self.layer.cornerRadius = 12
        
        locationImage.contentMode = .scaleAspectFill
        locationImage.clipsToBounds = true
        locationImage.layer.cornerRadius = 12
        
        // Optional: Add shadow to containerView if you used one
         containerView.backgroundColor = .systemBackground
         containerView.layer.cornerRadius = 12
        
        
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        
        // Date label
        locationLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        locationLabel.textColor = .secondaryLabel
    }
    override func layoutSubviews() {
            super.layoutSubviews()
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    // Configure the cell with data
    func configure(with spot: PopularSpot) {
        locationImage.image = UIImage(named: spot.imageName)
        titleLabel.text = spot.title
        locationLabel.text = spot.location
    }
}
