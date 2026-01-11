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
        addIconToLabel(label: locationLabel, text: watchlist.location, iconName: "location.fill")
        
        // Date
        if isDateValid(start: watchlist.startDate, end: watchlist.endDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            
            let startStr = formatter.string(from: watchlist.startDate)
            let endStr = formatter.string(from: watchlist.endDate)
            let dateString = "\(startStr) - \(endStr)"
            
            addIconToLabel(label: dateLabel, text: dateString, iconName: "calendar")
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }
        
        // Badges
        addIconToLabel(label: leftBadgeLabel, text: "\(watchlist.birds.count)", iconName: "bird")
        addIconToLabel(label: rightBadgeLabel, text: "\(watchlist.observedCount)", iconName: "bird.fill")
        
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
    
    private func addIconToLabel(label: UILabel, text: String, iconName: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        let image = UIImage(systemName: iconName, withConfiguration: config)?
            .withTintColor(label.textColor, renderingMode: .alwaysOriginal)
        
        guard let safeImage = image else {
            label.text = text
            return
        }
        
        let attachment = NSTextAttachment(image: safeImage)
        let yOffset = (label.font.capHeight - safeImage.size.height).rounded() / 2
        attachment.bounds = CGRect(x: 0, y: yOffset - 1, width: safeImage.size.width, height: safeImage.size.height)
        
        let attrString = NSMutableAttributedString(attachment: attachment)
        attrString.append(NSAttributedString(string: "  " + text))
        
        label.attributedText = attrString
    }
}