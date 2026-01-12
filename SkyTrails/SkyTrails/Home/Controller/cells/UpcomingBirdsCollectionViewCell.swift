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
        self.backgroundColor = .clear
        setupUI()
    }
    
    private func setupUI() {
        self.backgroundColor = .clear
                contentView.backgroundColor = .clear
                contentView.layer.cornerRadius = 16
                contentView.layer.masksToBounds = false
                contentView.layer.shadowColor = UIColor.black.cgColor
                contentView.layer.shadowOpacity = 0.15
                contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
                contentView.layer.shadowRadius = 8
                contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        
            cardContainerView.backgroundColor = .systemBackground
            cardContainerView.layer.cornerRadius = 16
            cardContainerView.layer.masksToBounds = true


           birdImageView.contentMode = .scaleAspectFill
           birdImageView.clipsToBounds = true
           birdImageView.layer.cornerRadius = 12
           

           titleLabel.numberOfLines = 1
           titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)         
           
           dateLabel.textColor = .secondaryLabel
           
         
       }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
    
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
       
       // MARK: - Configuration Method
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
