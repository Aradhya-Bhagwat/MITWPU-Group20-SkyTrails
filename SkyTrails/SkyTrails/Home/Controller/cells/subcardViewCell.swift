//
//  subcardViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 17/02/26.
//

import UIKit

class subcardViewCell: UICollectionViewCell {
    
    static let identifier = "subcardViewCell"
    
    // Expanded View Outlets
    @IBOutlet weak var expandedView: UIView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var birdNameLabel: UILabel!
    @IBOutlet weak var statusBadgeContainer: UIView!
    @IBOutlet weak var badgeIconImageView: UIImageView!
    @IBOutlet weak var badgeTitleLabel: UILabel!
    @IBOutlet weak var badgeSubtitleLabel: UILabel!
    @IBOutlet weak var sightabilityIconLabel: UILabel!
    @IBOutlet weak var sightabilityTextLabel: UILabel!
    
    // Compact View Outlets
    @IBOutlet weak var compactView: UIView!
    @IBOutlet weak var compactBirdImageView: UIImageView!
    @IBOutlet weak var compactBirdNameLabel: UILabel!
    @IBOutlet weak var compactStatusIconLabel: UILabel!
    
    var isExpanded: Bool = true {
        didSet {
            updateViewState()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }
    
    private func updateViewState() {
        expandedView?.isHidden = !isExpanded
        compactView?.isHidden = isExpanded
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFonts()
        updateExpandedBadgeCircle()
        updateExpandedBadgeIcon()
    }
    
    private func updateFonts() {
        let currentHeight = self.bounds.height
        let ratio = currentHeight / 90.0
        let fontSize = max(12, 12 * ratio)
        
        birdNameLabel.font = .systemFont(ofSize: fontSize, weight: .semibold)
        badgeTitleLabel.font = .systemFont(ofSize: fontSize)
        badgeSubtitleLabel.font = .systemFont(ofSize: fontSize)
        sightabilityIconLabel.font = .systemFont(ofSize: fontSize)
        sightabilityTextLabel.font = .systemFont(ofSize: fontSize)
        
        compactBirdNameLabel.font = .systemFont(ofSize: fontSize, weight: .semibold)
        updateCompactStatusIcon(pointSize: fontSize)
    }
    private func setupAppearance() {
            contentView.backgroundColor = .systemBackground
            contentView.layer.cornerRadius = 12
            contentView.layer.masksToBounds = true
            
            birdImageView.layer.cornerRadius = 8
            birdImageView.contentMode = .scaleAspectFill
            
            statusBadgeContainer.layer.cornerRadius = 6
            compactBirdImageView?.layer.cornerRadius = 8
            compactBirdImageView?.clipsToBounds = true
            
            // Border for the cell to distinguish it from the parent card
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = UIColor.systemGray6.cgColor
        
            let config = UIImage.SymbolConfiguration(scale: .small)
            
            // 2. Load the image (Note: "binoculars.fill" is plural)
            if let image = UIImage(systemName: "binoculars.fill", withConfiguration: config) {
                // 3. Create an attachment
                let attachment = NSTextAttachment()
                attachment.image = image.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
                sightabilityIconLabel.attributedText = NSAttributedString(attachment: attachment)
            }
            updateExpandedBadgeIcon()
            updateCompactStatusIcon(pointSize: 12)
            updateViewState()
        }
        
        func configure(with birdData: BirdSpeciesDisplay) {
            print("🐦 [PredictionDebug] subcardViewCell configure: \(birdData.birdName)")
            birdNameLabel.text = birdData.birdName
            compactBirdNameLabel?.text = birdData.statusBadge.title
            
            if let image = UIImage(named: birdData.birdImageName) {
                birdImageView.image = image
                compactBirdImageView?.image = image
                print("🐦 [PredictionDebug]   ✅ Image loaded: \(birdData.birdImageName)")
            } else {
                birdImageView.image = UIImage(systemName: "bird.fill")
                birdImageView.tintColor = .systemGray4
                compactBirdImageView?.image = UIImage(systemName: "bird.fill")
                compactBirdImageView?.tintColor = .systemGray4
                print("⚠️ [PredictionDebug]   ❌ Image NOT FOUND: \(birdData.birdImageName)")
            }
            
            // Badge
            badgeTitleLabel.text = birdData.statusBadge.title
            badgeSubtitleLabel.text = birdData.statusBadge.subtitle
            
            let badgeColor: UIColor
            switch birdData.statusBadge.backgroundColorName {
            case "systemGreen":  badgeColor = .systemGreen
            case "systemBlue":   badgeColor = .systemBlue
            case "systemOrange": badgeColor = .systemOrange
            case "systemPink", "BadgePink": badgeColor = .systemPink
            default:
                // Fall back to named asset, then grey
                badgeColor = UIColor(named: birdData.statusBadge.backgroundColorName) ?? .systemGray4
            }
            statusBadgeContainer.backgroundColor = badgeColor.withAlphaComponent(0.15)
            print("🐦 [PredictionDebug]   Badge color: \(birdData.statusBadge.backgroundColorName)")
            
            updateExpandedBadgeIcon()
            
            // Sightability
            sightabilityTextLabel.text = "Sightability - \(birdData.sightabilityPercent)%"
            print("🐦 [PredictionDebug]   Sightability set to \(birdData.sightabilityPercent)%")
        }
    
    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }
    
    private func updateCompactStatusIcon(pointSize: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let image = UIImage(systemName: "bird.circle.fill", withConfiguration: config)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal) else { return }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -1, width: image.size.width, height: image.size.height)
        compactStatusIconLabel?.attributedText = NSAttributedString(attachment: attachment)
    }
    
    private func updateExpandedBadgeCircle() {
        // The icon container view is square in XIB, so half-size corner radius creates a true circle.
        let circleHost = badgeIconImageView.superview
        circleHost?.layer.cornerRadius = min(circleHost?.bounds.width ?? 0, circleHost?.bounds.height ?? 0) / 2
        circleHost?.clipsToBounds = true
    }
    
    private func updateExpandedBadgeIcon() {
        let side = max(12, min(badgeIconImageView.bounds.width, badgeIconImageView.bounds.height))
        let config = UIImage.SymbolConfiguration(pointSize: side * 0.8, weight: .regular)
        badgeIconImageView.image = UIImage(systemName: "bird.circle.fill", withConfiguration: config)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
    }
    }
