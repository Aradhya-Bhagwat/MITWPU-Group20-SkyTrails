//
//  SpotsToVisitCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class GridSpotsToVisitCollectionViewCell: UICollectionViewCell {

    static let identifier = "GridSpotsToVisitCollectionViewCell"

    @IBOutlet weak var locationImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var containerView: UIView! 

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
        contentView.layer.shadowOpacity = 0.15
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 8  
        
        self.layer.cornerRadius = 12
        
        locationImage.contentMode = .scaleAspectFill
        locationImage.clipsToBounds = true
        locationImage.layer.cornerRadius = 12
        
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        
        titleLabel.numberOfLines = 1
        titleLabel.textColor = .label
        
        locationLabel.textColor = .secondaryLabel
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath

        let currentWidth = self.bounds.width
        let titleRatio: CGFloat = 17.0 / 200.0
        let locationRatio: CGFloat = 12.0 / 200.0
        let calculatedTitleSize = currentWidth * titleRatio
        let calculatedLocSize = currentWidth * locationRatio

        titleLabel.font = UIFont.systemFont(
            ofSize: min(calculatedTitleSize, 30.0),
            weight: .semibold
        )
        
        locationLabel.font = UIFont.systemFont(
            ofSize: min(calculatedLocSize, 18.0),
            weight: .regular
        )
    }
 
    func configure(with spot: PopularSpot) {
        locationImage.image = UIImage(named: spot.imageName)
        titleLabel.text = spot.title
        locationLabel.text = spot.location
    }
}
