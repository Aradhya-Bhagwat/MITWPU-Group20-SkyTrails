//
//  BirdSmartCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class BirdSmartCell: UITableViewCell {
    
    static let identifier = "BirdSmartCell"

    // MARK: - IBOutlets
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    var avatarStackView: UIStackView!
    var shouldShowAvatars: Bool = true {
        didSet {
            avatarStackView.isHidden = !shouldShowAvatars
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        setupAvatarStackView()
        avatarStackView.isHidden = !shouldShowAvatars // Set initial state
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }

    private func setupUI() {
        // Container Styling
        containerView.layer.cornerRadius = 12
        // Shadow can be added here or in the storyboard if preferred, similar to the reference cell
        
        // Image Styling
        birdImageView.layer.cornerRadius = 12
        birdImageView.clipsToBounds = true
        birdImageView.contentMode = .scaleAspectFill
        birdImageView.backgroundColor = .systemGray5
        
        // Text Styling
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        
        dateLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dateLabel.textColor = .secondaryLabel
        
        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = .secondaryLabel
    }
    
    private func setupAvatarStackView() {
        avatarStackView = UIStackView()
        avatarStackView.axis = .horizontal
        avatarStackView.spacing = -10 // Overlap effect
        avatarStackView.alignment = .center
        avatarStackView.distribution = .fillEqually
        avatarStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(avatarStackView)
        
        NSLayoutConstraint.activate([
            avatarStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            avatarStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            avatarStackView.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    func configure(with bird: Bird) {
        titleLabel.text = bird.name
        
        // Image
        if let imageName = bird.images.first {
            birdImageView.image = UIImage(named: imageName)
        } else {
            birdImageView.image = nil 
        }

        // Date
        if let firstDate = bird.date.first {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy"
            let dateString = formatter.string(from: firstDate)
            addIconToLabel(label: dateLabel, text: dateString, iconName: "calendar")
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }

        // Location
        if let locationName = bird.location.first {
            addIconToLabel(label: locationLabel, text: locationName, iconName: "location.fill")
            locationLabel.isHidden = false
        } else {
            locationLabel.isHidden = true
        }
        
        // Avatars - only show if `shouldShowAvatars` is true for this cell
        if shouldShowAvatars {
            setupAvatars(images: bird.observedBy ?? [])
        } else {
            // Ensure avatars are hidden and cleared if not supposed to be shown
            avatarStackView.isHidden = true
            avatarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }
    }
    
    private func setupAvatars(images: [String]) {
        // Clear existing views
        avatarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard !images.isEmpty else {
            avatarStackView.isHidden = true // Hide if no images
            return
        }
        
        avatarStackView.isHidden = false // Show if images exist
        
        let maxDisplay = 2 // Max 2 users + overflow
        let imageSize: CGFloat = 30
        
        let shouldShowCountBadge = images.count > maxDisplay
        let displayCount = shouldShowCountBadge ? maxDisplay : images.count // Show 2 images if more than 2, else show all
        
        // 1. Add User Images
        for i in 0..<displayCount {
            let imageName = images[i]
            let imageView = UIImageView()
            // Check if it's a system symbol or named asset
            if let systemImage = UIImage(systemName: imageName) {
                imageView.image = systemImage.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
                imageView.backgroundColor = .secondarySystemBackground
            } else {
                imageView.image = UIImage(named: imageName)
            }
            
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = imageSize / 2
            imageView.clipsToBounds = true
            imageView.layer.borderWidth = 2
            imageView.layer.borderColor = UIColor.white.cgColor
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
            
            avatarStackView.addArrangedSubview(imageView)
        }
        
        // 2. Add "+X" Badge if needed
        if shouldShowCountBadge {
            let remaining = images.count - displayCount
            let badgeLabel = UILabel()
            badgeLabel.text = "+\(remaining)"
            badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
            badgeLabel.textColor = .white
            badgeLabel.textAlignment = .center
            
            let badgeView = UIView()
            badgeView.backgroundColor = .systemGray
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
            
            badgeView.translatesAutoresizingMaskIntoConstraints = false
            badgeView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
            badgeView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
            
            avatarStackView.addArrangedSubview(badgeView)
        }
    }
    
    // Helper
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
        attrString.append(NSAttributedString(string: "  " + text)) // Extra space after icon
        
        label.attributedText = attrString
    }
}
