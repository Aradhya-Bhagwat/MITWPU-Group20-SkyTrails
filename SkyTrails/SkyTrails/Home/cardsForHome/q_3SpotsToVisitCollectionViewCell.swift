//
//  q_3SpotsToVisitCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class q_3SpotsToVisitCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardContainerView2: UIView!
    @IBOutlet weak var birdImageView2: UIImageView!
    @IBOutlet weak var titleLabel2: UILabel!
    @IBOutlet weak var dateLabel2: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.backgroundColor = .clear
        setupUI()   
    }
    private func setupUI() {
        self.backgroundColor = .clear
        contentView.backgroundColor = .systemBackground
                
                // Round the corners of the card
                contentView.layer.cornerRadius = 16
                
                // IMPORTANT: Allow the shadow to spill outside the bounds
                contentView.layer.masksToBounds = false
                
                // Add the Shadow
                contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.15  // Adjust for darkness (0.1 to 0.2 is good)
                contentView.layer.shadowOffset = CGSize(width: 0, height: 4) // Shadow moves down slightly
                contentView.layer.shadowRadius = 8 // Softness of the shadow
                
                // Optimization: improves scrolling performance
                contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        
        cardContainerView2.backgroundColor = .systemBackground
            cardContainerView2.layer.cornerRadius = 16
            
            // This view MUST clip its content (the image) to keep the corners clean.
            cardContainerView2.layer.masksToBounds = true

        // Image styling
           birdImageView2.contentMode = .scaleAspectFill
           birdImageView2.clipsToBounds = true
           birdImageView2.layer.cornerRadius = 12
           
           // Title label
           titleLabel2.numberOfLines = 1
           titleLabel2.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
           titleLabel2.textColor = .label
           
           // Date label
           dateLabel2.font = UIFont.systemFont(ofSize: 12, weight: .regular)
           dateLabel2.textColor = .secondaryLabel
           
         
       }
    override func layoutSubviews() {
            super.layoutSubviews()
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    
    override func prepareForReuse() {
           super.prepareForReuse()
           
           birdImageView2.image = nil
           titleLabel2.text = nil
           dateLabel2.text = nil
       }
    private func createIconString(text: String, iconName: String, color: UIColor, fontSize: CGFloat) -> NSAttributedString {
            let config = UIImage.SymbolConfiguration(pointSize: fontSize * 0.9, weight: .semibold)
            
            guard let icon = UIImage(systemName: iconName, withConfiguration: config)?
                .withTintColor(color, renderingMode: .alwaysOriginal) else { return NSAttributedString(string: text) }
            
            let attachment = NSTextAttachment(image: icon)
            let yOffset = (fontSize - icon.size.height) / 2.0 - 2
            attachment.bounds = CGRect(x: 0, y: yOffset, width: icon.size.width, height: icon.size.height)
            
            let completeString = NSMutableAttributedString(attachment: attachment)
            // Add a space after the icon by adding a space character to the text
            completeString.append(NSAttributedString(string: " " + text, attributes: [.foregroundColor: color]))
            
            return completeString
        }
       
    // MARK: - Configuration Method
    func configure(image: UIImage?, title: String, date: String) {
        birdImageView2.image = image
        titleLabel2.text = title
        let locationColor = dateLabel2.textColor ?? .secondaryLabel
                let locationFontSize = dateLabel2.font.pointSize
                
                dateLabel2.attributedText = createIconString(
                    text: date,
                    iconName: "mappin.and.ellipse", // Use map pin icon for location
                    color: locationColor,
                    fontSize: locationFontSize
                )
    }
    
}


