//
//  q_2UpcomingBirdsCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class q_2UpcomingBirdsCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var cardContainerView: UIView!
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .clear
        setupUI()        // Initialization code
    }
    
    private func setupUI() {
        self.backgroundColor = .clear
                contentView.backgroundColor = .clear
                contentView.layer.cornerRadius = 16
                contentView.layer.masksToBounds = false
                contentView.layer.shadowColor = UIColor.black.cgColor
                contentView.layer.shadowOpacity = 0.15  // Adjust for darkness (0.1 to 0.2 is good)
                contentView.layer.shadowOffset = CGSize(width: 0, height: 4) // Shadow moves down slightly
                contentView.layer.shadowRadius = 8 // Softness of the shadow
                
                // Optimization: improves scrolling performance
                contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        
            cardContainerView.backgroundColor = .systemBackground
            cardContainerView.layer.cornerRadius = 16
            
            // This view MUST clip its content (the image) to keep the corners clean.
            cardContainerView.layer.masksToBounds = true

        // Image styling
           birdImageView.contentMode = .scaleAspectFill
           birdImageView.clipsToBounds = true
           birdImageView.layer.cornerRadius = 12
           
           // Title label
           titleLabel.numberOfLines = 1
           titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
           titleLabel.textColor = .label
           
           // Date label
           dateLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
           dateLabel.textColor = .secondaryLabel
           
         
       }
    override func layoutSubviews() {
            super.layoutSubviews()
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
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
            // Add a space after the icon by adding a space character to the text
            completeString.append(NSAttributedString(string: " " + text, attributes: [.foregroundColor: color]))
            
            return completeString
        }
       
       // MARK: - Configuration Method
       func configure(image: UIImage?, title: String, date: String) {
           birdImageView.image = image
           titleLabel.text = title
           let dateColor = dateLabel.textColor ?? .secondaryLabel
                   let dateFontSize = dateLabel.font.pointSize
           dateLabel.attributedText = createIconString(
                       text: date,
                       iconName: "calendar", // Use calendar icon
                       color: dateColor,
                       fontSize: dateFontSize
                       )
       }
    
}
