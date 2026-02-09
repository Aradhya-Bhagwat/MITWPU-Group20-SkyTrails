//
//  q_3SpotsToVisitCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class SpotsToVisitCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardContainerView2: UIView!
    @IBOutlet weak var birdImageView2: UIImageView!
    @IBOutlet weak var titleLabel2: UILabel!
    @IBOutlet weak var dateLabel2: UILabel!
    
    private var currentSpeciesCount: Int = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()   
    }
    private func setupUI() {
        self.backgroundColor = .clear
        
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.15
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        
        cardContainerView2.backgroundColor = .systemBackground
        cardContainerView2.layer.cornerRadius = 16
        cardContainerView2.layer.masksToBounds = true
        
        birdImageView2.contentMode = .scaleAspectFill
        birdImageView2.clipsToBounds = true
        birdImageView2.layer.cornerRadius = 12
        
        titleLabel2.numberOfLines = 1
        titleLabel2.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel2.textColor = .label
        
        dateLabel2.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        dateLabel2.textColor = .secondaryLabel
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard titleLabel2 != nil, dateLabel2 != nil else { return }
        
        contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        
        let currentWidth = self.bounds.width
        let titleRatio: CGFloat = 17.0 / 200.0
        let dateRatio: CGFloat = 12.0 / 200.0
        
        titleLabel2.font = UIFont.systemFont(
            ofSize: currentWidth * titleRatio,
            weight: .semibold
        )
        
        let dynamicDateSize = currentWidth * dateRatio
        dateLabel2.font = UIFont.systemFont(ofSize: dynamicDateSize, weight: .regular)
        updateSpeciesLabel(count: currentSpeciesCount, fontSize: dynamicDateSize)
        
    }
    private func updateSpeciesLabel(count: Int, fontSize: CGFloat) {
            let text = "\(count) Species active now"
            dateLabel2.attributedText = createIconString(
                text: text,
                iconName: "bird.fill", // 💡 Changed to bird icon
                color: .systemGreen,   // 💡 Changed to green to indicate "live" data
                fontSize: fontSize
            )
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
            completeString.append(NSAttributedString(string: " " + text, attributes: [.foregroundColor: color]))
        
            return completeString
        }
    
    func configure(image: UIImage?, title: String, speciesCount: Int) {
            self.birdImageView2.image = image
            self.titleLabel2.text = title
            self.currentSpeciesCount = speciesCount // Save the state
            
            updateSpeciesLabel(count: speciesCount, fontSize: dateLabel2.font.pointSize)
        }
    
}


