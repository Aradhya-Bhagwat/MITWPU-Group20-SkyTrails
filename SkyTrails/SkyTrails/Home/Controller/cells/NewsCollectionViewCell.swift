//
//  q_4NewsCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class NewsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var newsImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    
    private var gradientLayer: CAGradientLayer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        setupAppearance()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard newsImageView != nil else { return }
        applyGradientLayer()
        if traitCollection.userInterfaceStyle != .dark {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        }
    }
    
    func configure(with news: NewsItem) {
        titleLabel.text = news.title
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        
        summaryLabel.text = news.summary
        summaryLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        summaryLabel.textColor = .white.withAlphaComponent(0.9)
        summaryLabel.numberOfLines = 3
        
        if let image = UIImage(named: news.imageName) {
            newsImageView.image = image
        } else {
            newsImageView.image = UIImage(systemName: "photo")
            newsImageView.tintColor = .systemGray
        }
        
        containerView.bringSubviewToFront(titleLabel)
        containerView.bringSubviewToFront(summaryLabel)
    }
    
    private func applyGradientLayer() {
        
        gradientLayer?.removeFromSuperlayer()
        let gradient = CAGradientLayer()
        self.gradientLayer = gradient
        
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.2).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        
        gradient.locations = [0.5, 1.0]
        gradient.frame = newsImageView.bounds
        
        newsImageView.layer.insertSublayer(gradient, at: 0)
    }

    private func setupAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = cardColor
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        layer.cornerRadius = 16
        layer.masksToBounds = false

        if isDarkMode {
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
            layer.shadowPath = nil
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.08
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 6
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        }
    }

}
