//
//  UpcomingBirdGridCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class GridUpcomingGridCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "GridUpcomingGridCollectionViewCell"
    
    @IBOutlet weak var birImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var DateLabel: UILabel!
    @IBOutlet weak var containerView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
     
        setupStyle()
    }
    private func setupStyle() {
        
        self.backgroundColor = .clear
        self.layer.cornerRadius = 12
        
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.15
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 8
        
        birImage.contentMode = .scaleAspectFill
        birImage.clipsToBounds = true
        birImage.layer.cornerRadius = 12

        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        
        titleLabel.textColor = .label
        
        DateLabel.textColor = .secondaryLabel
    }
    


    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        
        let currentWidth = self.bounds.width
        let titleRatio: CGFloat = 17.0 / 200.0
        let locationRatio: CGFloat = 12.0 / 200.0
        let calculatedTitleSize = currentWidth * titleRatio
        let calculatedDateSize = currentWidth * locationRatio
        
        
        titleLabel.font = UIFont.systemFont(
            ofSize: min(calculatedTitleSize, 30.0),
            weight: .semibold
        )
        
        DateLabel.font = UIFont.systemFont(
            ofSize: min(calculatedDateSize, 18.0),
            weight: .regular
        )
    }
    func configure(with spot: UpcomingBird) {
        birImage.image = UIImage(named: spot.imageName)
        titleLabel.text = spot.title
        DateLabel.text = spot.date
    }

}
