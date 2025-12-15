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
    
    @IBOutlet var avatarImageViews: [UIImageView]! // Collection
    @IBOutlet weak var overflowBadgeView: UIView!
    @IBOutlet weak var overflowLabel: UILabel!
    @IBOutlet weak var avatarStackView: UIStackView! // Existing, now connected to Storyboard

    var shouldShowAvatars: Bool = true {
        didSet {
            // Updated to use the new avatarStackView outlet
            avatarStackView.isHidden = !shouldShowAvatars
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        // setupAvatarStackView() - Removed, UI is now in Storyboard
        // avatarStackView.isHidden = !shouldShowAvatars - Initial state handled by new setupAvatars
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
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .label
        
        dateLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dateLabel.textColor = .secondaryLabel
        
        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = .secondaryLabel

        // Configure all avatar image views initially
        avatarImageViews.forEach {
            $0.layer.cornerRadius = 15 // imageSize / 2 where imageSize = 30
            $0.clipsToBounds = true
            $0.layer.borderWidth = 2
            $0.layer.borderColor = UIColor.white.cgColor
        }

        // Configure overflow badge
        overflowBadgeView.layer.cornerRadius = 15
        overflowBadgeView.clipsToBounds = true
        overflowBadgeView.layer.borderWidth = 2
        overflowBadgeView.layer.borderColor = UIColor.white.cgColor
        overflowBadgeView.backgroundColor = .systemGray
        overflowLabel.textColor = .white
        overflowLabel.font = .systemFont(ofSize: 12, weight: .bold)
        overflowLabel.textAlignment = .center
    }
    
    // setupAvatarStackView() removed
    
    func configure(with bird: Bird) {
        titleLabel.text = bird.name
        
        // Image
        if let imageName = bird.images.first {
            if let assetImage = UIImage(named: imageName) {
                birdImageView.image = assetImage
            } else {
                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(imageName)
                if let docImage = UIImage(contentsOfFile: fileURL.path) {
                    birdImageView.image = docImage
                } else {
                    birdImageView.image = UIImage(systemName: "photo")
                }
            }
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
            avatarImageViews.forEach { $0.isHidden = true }
            overflowBadgeView.isHidden = true
        }
    }
    
    private func setupAvatars(images: [String]) {
        // Reset
        avatarImageViews.forEach { $0.isHidden = true }
        overflowBadgeView.isHidden = true
        
        guard !images.isEmpty else {
            avatarStackView.isHidden = true
            return
        }
        avatarStackView.isHidden = false
        
        let limit = avatarImageViews.count
        let displayCount = min(images.count, limit)
        
        for i in 0..<displayCount {
            let imgView = avatarImageViews[i]
            imgView.isHidden = false
            let name = images[i]
            if let sys = UIImage(systemName: name) {
                 imgView.image = sys.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            } else {
                 imgView.image = UIImage(named: name)
            }
        }
        
        if images.count > limit {
            overflowBadgeView.isHidden = false
            overflowLabel.text = "+\(images.count - limit)"
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
