//
//  PredictionButtonCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/03/26.
//

import UIKit

class PredictionButtonCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "PredictionButtonCollectionViewCell"
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var imageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
        setupAppearance()
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
    
    private func setupAppearance() {
        self.backgroundColor = .clear
        self.clipsToBounds = false
        
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
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
        
        guard containerView != nil, imageView != nil else { return }
        
        if traitCollection.userInterfaceStyle != .dark {
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    }
    
    func configure(with image: UIImage?) {
        imageView.image = image
    }

}
