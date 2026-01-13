//
//  CustomWatchlistCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class CustomWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "CustomWatchlistCollectionViewCell"
    
    // MARK: - IBOutlets
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var coverOverImageView: UIView!
    
    @IBOutlet weak var labelsStackView: UIStackView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var leftBadgeView: UIView!
    @IBOutlet weak var leftBadgeLabel: UILabel!
    
    @IBOutlet weak var rightBadgeView: UIView!
    @IBOutlet weak var rightBadgeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
    }
    
    private func setupUI() {
        // Container Styling
        let cardColor = UIColor.secondarySystemGroupedBackground
        containerView.backgroundColor = cardColor
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 6
        containerView.layer.masksToBounds = false
        
        // Image Styling
        coverImageView.layer.cornerRadius = 16
        coverImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coverImageView.clipsToBounds = true
        coverImageView.contentMode = .scaleAspectFill
        
        // Overlap View Styling
        coverOverImageView.layer.cornerRadius = 16
        
        // Badge Styling
        setupBadge(leftBadgeView, label: leftBadgeLabel, color: .systemGreen, cornerRadius: 8)
        setupBadge(rightBadgeView, label: rightBadgeLabel, color: .systemBlue, cornerRadius: 8)
        
        // Text Styling
        titleLabel.textColor = .label
        [dateLabel, locationLabel].forEach {
            $0?.font = .systemFont(ofSize: 13, weight: .medium)
            $0?.textColor = .secondaryLabel
        }
    }
    
    private func setupBadge(_ view: UIView, label: UILabel, color: UIColor, cornerRadius: CGFloat) {
        view.layer.cornerRadius = cornerRadius
        view.backgroundColor = color.withAlphaComponent(0.15)
        view.layer.masksToBounds = true
        label.textColor = color
        label.font = .systemFont(ofSize: 12, weight: .bold)
    }
    
    func configure(with watchlist: Watchlist) {
        titleLabel.text = watchlist.title
        
        // Location
        locationLabel.addIcon(text: watchlist.location, iconName: "location.fill")
        
        // Date
        if isDateValid(start: watchlist.startDate, end: watchlist.endDate) {
            let startStr = DateFormatters.shortDate.string(from: watchlist.startDate)
            let endStr = DateFormatters.shortDate.string(from: watchlist.endDate)
            let dateString = "\(startStr) - \(endStr)"
            
            dateLabel.addIcon(text: dateString, iconName: "calendar")
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }
        
        // Badges
        leftBadgeLabel.addIcon(text: "\(watchlist.birds.count)", iconName: "bird")
        rightBadgeLabel.addIcon(text: "\(watchlist.observedCount)", iconName: "bird.fill")
        
        // Cover Image
        if let firstBird = watchlist.birds.first, let imageName = firstBird.images.first {
            coverImageView.image = UIImage(named: imageName)
        } else {
            coverImageView.image = nil
            coverImageView.backgroundColor = .systemGray5
        }
    }
    
    // MARK: - Helpers
    
    private func isDateValid(start: Date, end: Date) -> Bool {
        return start != end
    }
    
}