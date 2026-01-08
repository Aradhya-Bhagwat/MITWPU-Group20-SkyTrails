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
        
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        
        newsImageView.contentMode = .scaleAspectFill
        newsImageView.clipsToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyGradientLayer()
    }
    
    func configure(with news: NewsItem) {
        titleLabel.text = news.title
        // Using system font with bold weight as in the XIB, forcing white color for visibility over image
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
        
        // Ensure labels are on top
        containerView.bringSubviewToFront(titleLabel)
        containerView.bringSubviewToFront(summaryLabel)
    }
    
    private func applyGradientLayer() {
        gradientLayer?.removeFromSuperlayer()
        
        let gradient = CAGradientLayer()
        self.gradientLayer = gradient
        
        // Dark gradient similar to community cell for readability
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.2).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        
        gradient.locations = [0.5, 1.0]
        gradient.frame = newsImageView.bounds
        
        newsImageView.layer.insertSublayer(gradient, at: 0)
    }

}
