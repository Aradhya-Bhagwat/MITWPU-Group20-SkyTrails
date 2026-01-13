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
    

    @IBOutlet weak var imagesStackView: UIStackView!
    @IBOutlet weak var imageView1: UIImageView!
    @IBOutlet weak var imageView2: UIImageView!
    @IBOutlet weak var imageView3: UIImageView!
    
    // Badges Outlets
    @IBOutlet weak var greenBadgeView: UIView!
    @IBOutlet weak var greenBadgeLabel: UILabel!
    @IBOutlet weak var blueBadgeView: UIView!
    @IBOutlet weak var blueBadgeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
		self.contentView.shadow = true
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
        
        // Images Container Styling (Masking top corners)
        imagesStackView.layer.cornerRadius = 16
        imagesStackView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        imagesStackView.clipsToBounds = true
        imagesStackView.backgroundColor = .secondarySystemBackground
        
        // Images Styling
        [imageView1, imageView2, imageView3].forEach {
            $0?.contentMode = .scaleAspectFill
            $0?.clipsToBounds = true
        }
        
        // Labels Styling
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        
        // Badges Styling
        setupBadge(greenBadgeView, label: greenBadgeLabel, color: .systemGreen)
        setupBadge(blueBadgeView, label: blueBadgeLabel, color: .systemBlue)
    }
    
    private func setupBadge(_ view: UIView, label: UILabel, color: UIColor) {
        view.layer.cornerRadius = 8
        view.backgroundColor = color.withAlphaComponent(0.15)
        view.layer.masksToBounds = true
        label.textColor = color
        label.font = .systemFont(ofSize: 12, weight: .bold)
    }
    
    func configure(observedCount: Int, toObserveCount: Int, images: [UIImage?]) {
        // Configure Images
        let availableImages = images.compactMap { $0 }
        let count = min(availableImages.count, 3)
        
        [imageView1, imageView2, imageView3].forEach { $0?.isHidden = true }
        
        if count == 0 {
             imageView1.isHidden = false
             imageView1.image = nil
             imageView1.backgroundColor = .systemGray6
        } else {
             if count >= 1 {
                 imageView1.isHidden = false
                 imageView1.image = availableImages[0]
             }
             if count >= 2 {
                 imageView2.isHidden = false
                 imageView2.image = availableImages[1]
             }
             if count >= 3 {
                 imageView3.isHidden = false
                 imageView3.image = availableImages[2]
             }
        }
        
        // Configure Badges
        // Green: To Observe (birds added/not yet observed)
        greenBadgeLabel.addIcon(text: "\(toObserveCount)", iconName: "bird")

        // Blue: Observed
        blueBadgeLabel.addIcon(text: "\(observedCount)", iconName: "bird.fill")
    }
}
