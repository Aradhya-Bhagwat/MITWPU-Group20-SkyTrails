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
        setupTraitChangeHandling()
        setupStyle()
        applySemanticAppearance()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }
    private func setupStyle() {
        
        self.backgroundColor = .clear
        self.layer.cornerRadius = 12
        
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        
        birImage.contentMode = .scaleAspectFill
        birImage.clipsToBounds = true
        birImage.layer.cornerRadius = 12

        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true
        
        titleLabel.textColor = .label
        
        DateLabel.textColor = .secondaryLabel
    }

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = cardColor

        if isDarkMode {
            contentView.layer.shadowOpacity = 0
            contentView.layer.shadowRadius = 0
            contentView.layer.shadowOffset = .zero
            contentView.layer.shadowPath = nil
        } else {
            contentView.layer.shadowColor = UIColor.black.cgColor
            contentView.layer.shadowOpacity = 0.08
            contentView.layer.shadowOffset = CGSize(width: 0, height: 3)
            contentView.layer.shadowRadius = 6
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    }
    


    override func layoutSubviews() {
        super.layoutSubviews()
        
        if traitCollection.userInterfaceStyle != .dark {
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
        
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
