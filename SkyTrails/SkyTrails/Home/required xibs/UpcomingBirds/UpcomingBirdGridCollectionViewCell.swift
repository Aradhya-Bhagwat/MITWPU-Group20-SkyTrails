//
//  UpcomingBirdGridCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class UpcomingBirdGridCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "UpcomingBirdGridCollectionViewCell"
    
    @IBOutlet weak var birImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var DateLabel: UILabel!
    @IBOutlet weak var containerView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
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
        
        birImage.contentMode = .scaleAspectFill
        birImage.clipsToBounds = true
        birImage.layer.cornerRadius = 12
        
        // Optional: Add shadow to containerView if you used one
         containerView.backgroundColor = .systemBackground
         containerView.layer.cornerRadius = 12
        
        
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        
        // Date label
        DateLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        DateLabel.textColor = .secondaryLabel
    }
    
    override func layoutSubviews() {
            super.layoutSubviews()
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    // Configure the cell with data
    func configure(with spot: UpcomingBird) {
        birImage.image = UIImage(named: spot.imageName)
        titleLabel.text = spot.title
        DateLabel.text = spot.date
    }

}
