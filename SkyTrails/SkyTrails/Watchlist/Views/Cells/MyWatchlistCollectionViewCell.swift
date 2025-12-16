//
//  MyWatchlistCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class MyWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "MyWatchlistCollectionViewCell"

    @IBOutlet weak var mainImage: UIImageView!
    @IBOutlet weak var upcomingLabel: UILabel!
    @IBOutlet weak var discoveredLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var observedBadgeView: UIView!
    @IBOutlet weak var watchlistBadgeView: UIView!
    
    @IBOutlet weak var observedSpeicesCountLabel: UILabel!
    @IBOutlet weak var watchlistSpeciesCountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        setupUI()
    }
    
    private func setupUI() {
        // Container Styling
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.masksToBounds = false
        
        // Image Styling
        mainImage.contentMode = .scaleAspectFill
        mainImage.clipsToBounds = true
        mainImage.layer.cornerRadius = 16
        mainImage.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        
        // Badge Backgrounds
        observedBadgeView.layer.cornerRadius = 8
        observedBadgeView.layer.masksToBounds = true
        observedBadgeView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        
        watchlistBadgeView.layer.cornerRadius = 8
        watchlistBadgeView.layer.masksToBounds = true
        watchlistBadgeView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        
        // Badge Text Colors
        observedSpeicesCountLabel.textColor = UIColor.systemBlue
        observedSpeicesCountLabel.alpha = 1
        
        watchlistSpeciesCountLabel.textColor = UIColor.systemGreen
        watchlistSpeciesCountLabel.alpha = 1
    }
    
    func configure(discoveredText: String,
                   upcomingText: String,
                   dateText: String,
                   observedCount: Int,
                   watchlistCount: Int,
                   image: UIImage?) {
        
        discoveredLabel.text = discoveredText
        upcomingLabel.text = upcomingText
        dateLabel.text = dateText
        mainImage.image = image
        
        // Observed Badge
        let observedString = createIconString(
            text: " \(observedCount)",
            iconName: "bird.fill",
            color: .systemBlue,
            fontSize: observedSpeicesCountLabel.font.pointSize
        )
        observedSpeicesCountLabel.attributedText = observedString
        
        // Watchlist Badge
        let watchlistString = createIconString(
            text: " \(watchlistCount)",
            iconName: "bird",
            color: .systemGreen,
            fontSize: watchlistSpeciesCountLabel.font.pointSize
        )
        watchlistSpeciesCountLabel.attributedText = watchlistString
    }
    
    private func createIconString(text: String, iconName: String, color: UIColor, fontSize: CGFloat) -> NSAttributedString {
        let config = UIImage.SymbolConfiguration(pointSize: fontSize * 0.9, weight: .semibold)
        
        guard let icon = UIImage(systemName: iconName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return NSAttributedString(string: text) }
        
        let attachment = NSTextAttachment(image: icon)
        let yOffset = (fontSize - icon.size.height) / 2.0 - 2
        attachment.bounds = CGRect(x: 0, y: yOffset, width: icon.size.width, height: icon.size.height)
        
        let completeString = NSMutableAttributedString(attachment: attachment)
        completeString.append(NSAttributedString(string: text, attributes: [.foregroundColor: color]))
        
        return completeString
    }
}