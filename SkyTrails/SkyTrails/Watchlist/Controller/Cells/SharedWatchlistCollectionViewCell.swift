//
//  SharedWatchlistCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class SharedWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "SharedWatchlistCollectionViewCell"
    
    // MARK: - IBOutlets
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var mainImageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var greenBadgeView: UIView!
    @IBOutlet weak var greenBadgeLabel: UILabel!
    @IBOutlet weak var blueBadgeView: UIView!
    @IBOutlet weak var blueBadgeLabel: UILabel!
    
    @IBOutlet weak var avatarStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
        // Container Styling
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.masksToBounds = false
        
        // Main Image Styling
        mainImageView.layer.cornerRadius = 16
        mainImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        mainImageView.clipsToBounds = true
        mainImageView.contentMode = .scaleAspectFill
        
        // Badge Styling
        setupBadge(greenBadgeView, label: greenBadgeLabel, color: .systemGreen)
        setupBadge(blueBadgeView, label: blueBadgeLabel, color: .systemBlue)
        
        // Label Styling
        dateLabel.textColor = .secondaryLabel
        locationLabel.textColor = .secondaryLabel
    }
    
    private func setupBadge(_ view: UIView, label: UILabel, color: UIColor) {
        view.backgroundColor = color.withAlphaComponent(0.15)
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        
        label.textColor = color
        label.font = .systemFont(ofSize: 12, weight: .bold)
    }
    
    // MARK: - Configuration
    func configure(title: String,
                   location: String,
                   dateRange: String,
                   mainImage: UIImage?,
                   stats: SharedWatchlistStats,
                   userImages: [UIImage]) {
        
        titleLabel.text = title
        self.mainImageView.image = mainImage
        
        addIconToLabel(label: locationLabel, text: location, iconName: "location.fill")
        addIconToLabel(label: dateLabel, text: dateRange, iconName: "calendar")
        
        addIconToLabel(label: greenBadgeLabel, text: "\(stats.greenValue)", iconName: "bird")
        addIconToLabel(label: blueBadgeLabel, text: "\(stats.blueValue)", iconName: "bird.fill")
        
        setupAvatars(images: userImages)
    }
    
    private func setupAvatars(images: [UIImage]) {
        avatarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let maxDisplay = 3
        let imageSize: CGFloat = 30
        
        let shouldShowCountBadge = images.count > maxDisplay
        let displayCount = shouldShowCountBadge ? maxDisplay - 1 : images.count
        
        for i in 0..<displayCount {
            let imageView = UIImageView(image: images[i])
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = imageSize / 2
            imageView.clipsToBounds = true
            imageView.layer.borderWidth = 2
            imageView.layer.borderColor = UIColor.white.cgColor
            
            imageView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
            
            avatarStackView.addArrangedSubview(imageView)
        }
        
        if shouldShowCountBadge {
            let remaining = images.count - displayCount
            let badgeLabel = UILabel()
            badgeLabel.text = "+\(remaining)"
            badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
            badgeLabel.textColor = .white
            badgeLabel.textAlignment = .center
            
            let badgeView = UIView()
            badgeView.backgroundColor = UIColor.systemGray
            badgeView.layer.cornerRadius = imageSize / 2
            badgeView.clipsToBounds = true
            badgeView.layer.borderWidth = 2
            badgeView.layer.borderColor = UIColor.white.cgColor
            
            badgeView.addSubview(badgeLabel)
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                badgeLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
                badgeLabel.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor)
            ])
            
            badgeView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
            badgeView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
            
            avatarStackView.addArrangedSubview(badgeView)
        }
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