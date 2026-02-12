//
//  q_2UpcomingBirdsCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class UpcomingBirdsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardContainerView: UIView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        applySemanticAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        applySemanticAppearance()
    }
    
    private func setupUI() {
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        cardContainerView.backgroundColor = .secondarySystemBackground
        cardContainerView.layer.cornerRadius = 16
        cardContainerView.layer.masksToBounds = true

        birdImageView.contentMode = .scaleAspectFill
        birdImageView.clipsToBounds = true
        birdImageView.layer.cornerRadius = 12
           
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
           
        dateLabel.textColor = .secondaryLabel
        
        }

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        cardContainerView.backgroundColor = .secondarySystemBackground

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
        
        // Guard against uninitialized outlets during layout passes
        guard cardContainerView != nil, dateLabel != nil, titleLabel != nil else { return }
        if traitCollection.userInterfaceStyle != .dark {
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    
        let currentWidth = self.bounds.width
        let titleRatio: CGFloat = 17.0 / 200.0
        let dateRatio: CGFloat = 12.0 / 200.0
        
        titleLabel.font = UIFont.systemFont(
            ofSize: currentWidth * titleRatio,
            weight: .semibold
        )
        
        let dynamicDateSize = currentWidth * dateRatio
            dateLabel.font = UIFont.systemFont(ofSize: dynamicDateSize, weight: .regular)
        
        if let text = dateLabel.text {
            dateLabel.attributedText = createIconString(
                text: text,
                iconName: "calendar",
                color: .secondaryLabel,
                fontSize: dynamicDateSize
            )
        }
    }
    
    override func prepareForReuse() {
           super.prepareForReuse()
           
           birdImageView.image = nil
           titleLabel.text = nil
           dateLabel.text = nil
       }
    
    private func createIconString(text: String, iconName: String, color: UIColor, fontSize: CGFloat) -> NSAttributedString {
            let config = UIImage.SymbolConfiguration(pointSize: fontSize * 0.9, weight: .semibold)
            guard let icon = UIImage(systemName: iconName, withConfiguration: config)?
                .withTintColor(color, renderingMode: .alwaysOriginal) else { return NSAttributedString(string: text) }
            let attachment = NSTextAttachment(image: icon)
            let yOffset = (fontSize - icon.size.height) / 2.0 - 2
            attachment.bounds = CGRect(x: 0, y: yOffset, width: icon.size.width, height: icon.size.height)
            let completeString = NSMutableAttributedString(attachment: attachment)
            completeString.append(NSAttributedString(string: " " + text, attributes: [.foregroundColor: color]))
            
            return completeString
        }
       
       func configure(image: UIImage?, title: String, date: String) {
           birdImageView.image = image
           titleLabel.text = title
           let dateColor = dateLabel.textColor ?? .secondaryLabel
                   let dateFontSize = dateLabel.font.pointSize
           dateLabel.attributedText = createIconString(
                       text: date,
                       iconName: "calendar", 
                       color: dateColor,
                       fontSize: dateFontSize
                       )
       }
    
}
