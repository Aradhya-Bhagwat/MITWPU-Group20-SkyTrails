//
//  MyWatchlistCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class MyWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "MyWatchlistCollectionViewCell"

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    
    // Collage Outlets
    @IBOutlet weak var collageContainerView: UIView!
    @IBOutlet weak var stackViewMain: UIStackView!
    @IBOutlet weak var stackViewTop: UIStackView!
    @IBOutlet weak var stackViewBottom: UIStackView!
    @IBOutlet weak var imageView1: UIImageView!
    @IBOutlet weak var imageView2: UIImageView!
    @IBOutlet weak var imageView3: UIImageView!
    @IBOutlet weak var imageView4: UIImageView!
    
    // Stats Outlets
    @IBOutlet weak var observedLabel: UILabel!
    @IBOutlet weak var toObserveLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        setupUI()
    }
    
    private func setupUI() {
        // Container Styling
        containerView.backgroundColor = .secondarySystemGroupedBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.masksToBounds = false
        
        // Collage Styling
        collageContainerView.layer.cornerRadius = 16
        collageContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        collageContainerView.clipsToBounds = true
        
        [imageView1, imageView2, imageView3, imageView4].forEach {
            $0?.contentMode = .scaleAspectFill
            $0?.clipsToBounds = true
        }
        
        // Labels Styling
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        
        observedLabel.font = .systemFont(ofSize: 14)
        observedLabel.numberOfLines = 2
        
        toObserveLabel.font = .systemFont(ofSize: 14)
        toObserveLabel.numberOfLines = 2
    }
    
    func configure(observedCount: Int, toObserveCount: Int, images: [UIImage?]) {
        setupCollage(with: images.compactMap { $0 })
        
        // Observed Label
        let observedText = " \(observedCount) new birds observed this month"
        observedLabel.attributedText = createAttributedText(
            text: observedText,
            iconName: "bird.fill",
            color: .systemBlue
        )
        
        // To Observe Label
        let toObserveText = " \(toObserveCount) birds added to observe this month"
        toObserveLabel.attributedText = createAttributedText(
            text: toObserveText,
            iconName: "bird",
            color: .systemGreen
        )
    }
    
    private func setupCollage(with images: [UIImage]) {
        // Reset state
        [imageView1, imageView2, imageView3, imageView4].forEach {
            $0?.isHidden = true
            $0?.image = nil
        }
        stackViewTop.isHidden = true
        stackViewBottom.isHidden = true
        
        let count = min(images.count, 4)
        
        if count == 0 {
            // Placeholder state
            stackViewTop.isHidden = false
            imageView1.isHidden = false
            imageView1.image = UIImage(systemName: "photo")?.withTintColor(.tertiaryLabel, renderingMode: .alwaysOriginal)
            imageView1.contentMode = .center
            imageView1.backgroundColor = .secondarySystemBackground
            return
        }
        
        // Restore content mode
        [imageView1, imageView2, imageView3, imageView4].forEach { $0?.contentMode = .scaleAspectFill }
        
        // Populate images
        if count >= 1 {
            imageView1.image = images[0]
            imageView1.isHidden = false
            stackViewTop.isHidden = false
        }
        if count >= 2 {
            imageView2.image = images[1]
            imageView2.isHidden = false
        }
        if count >= 3 {
            imageView3.image = images[2]
            imageView3.isHidden = false
            stackViewBottom.isHidden = false
        }
        if count >= 4 {
            imageView4.image = images[3]
            imageView4.isHidden = false
        }
    }
    
    private func createAttributedText(text: String, iconName: String, color: UIColor) -> NSAttributedString {
        let fontSize: CGFloat = 14
        let config = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        
        guard let icon = UIImage(systemName: iconName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return NSAttributedString(string: text) }
        
        let attachment = NSTextAttachment(image: icon)
        let yOffset = (fontSize - icon.size.height) / 2.0 - 2
        attachment.bounds = CGRect(x: 0, y: yOffset, width: icon.size.width, height: icon.size.height)
        
        let completeString = NSMutableAttributedString(attachment: attachment)
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
        
        completeString.append(NSAttributedString(string: text, attributes: textAttributes))
        
        return completeString
    }
}