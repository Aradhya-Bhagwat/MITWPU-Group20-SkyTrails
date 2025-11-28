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

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
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
