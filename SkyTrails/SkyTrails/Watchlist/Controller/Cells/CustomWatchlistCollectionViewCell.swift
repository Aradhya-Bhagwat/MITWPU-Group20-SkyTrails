//
//  CustomWatchlistCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class CustomWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "CustomWatchlistCollectionViewCell"
    private var defaultCoverOverImageBackgroundColor: UIColor?
    
    // MARK: - IBOutlets
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var coverOverImageView: UIView!
    
    @IBOutlet weak var labelsStackView: UIStackView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var leftBadgeView: UIView!
    @IBOutlet weak var leftBadgeLabel: UILabel!
    
    @IBOutlet weak var rightBadgeView: UIView!
    @IBOutlet weak var rightBadgeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        defaultCoverOverImageBackgroundColor = coverOverImageView.backgroundColor
        setupUI()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
    }
    
    private func setupUI() {
        // Container Styling
        updateCardAppearance()
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = false
        
        // Image Styling
        coverImageView.layer.cornerRadius = 16
        coverImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coverImageView.clipsToBounds = true
        coverImageView.contentMode = .scaleAspectFill
        
        // Overlap View Styling
        coverOverImageView.layer.cornerRadius = 16
        
        // Badge Styling
        setupBadge(leftBadgeView, label: leftBadgeLabel, color: .systemGreen, cornerRadius: 8)
        setupBadge(rightBadgeView, label: rightBadgeLabel, color: .systemBlue, cornerRadius: 8)
        
        // Text Styling
        titleLabel.textColor = .label
        [dateLabel, locationLabel].forEach {
            $0?.font = .systemFont(ofSize: 13, weight: .medium)
            $0?.textColor = .secondaryLabel
        }
    }

    private func updateCardAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        containerView.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        coverOverImageView.backgroundColor = isDarkMode ? .secondarySystemBackground : defaultCoverOverImageBackgroundColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = isDarkMode ? 0 : 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 6
    }

    private func setupBadge(_ view: UIView, label: UILabel, color: UIColor, cornerRadius: CGFloat) {
        view.layer.cornerRadius = cornerRadius
        view.backgroundColor = color.withAlphaComponent(0.15)
        view.layer.masksToBounds = true
        label.textColor = color
        label.font = .systemFont(ofSize: 12, weight: .bold)
    }
    
    func configure(with dto: WatchlistSummaryDTO) {
        updateCardAppearance()
        titleLabel.text = dto.title
        
        // Location
        locationLabel.addIcon(text: dto.subtitle, iconName: "location.fill")
        
        // Date
        if !dto.dateText.isEmpty {
            dateLabel.addIcon(text: dto.dateText, iconName: "calendar")
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }
        
        // Badges
        leftBadgeLabel.addIcon(text: "\(dto.stats.totalCount)", iconName: "bird")
        rightBadgeLabel.addIcon(text: "\(dto.stats.observedCount)", iconName: "bird.fill")
        
        // Cover Image
		if let imageName = dto.image, let image = UIImage(named: imageName) {
			coverImageView.image = image
				// Reset contentsRect before calculating to ensure clean state
			coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
				// Apply alignment
			alignImageTop()
		} else {
			coverImageView.image = nil
			coverImageView.backgroundColor = .systemGray5
			coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
		}
    }
    
    // MARK: - Helpers
    
    private func isDateValid(start: Date, end: Date) -> Bool {
        return start != end
    }
    
		// MARK: - Image Alignment Helper
	
	private func alignImageTop() {
		guard let image = coverImageView.image else { return }
		
		let viewWidth = coverImageView.bounds.width
		let viewHeight = coverImageView.bounds.height
		
			// Guard to prevent division by zero if layout hasn't happened yet
		guard viewWidth > 0, viewHeight > 0, image.size.width > 0, image.size.height > 0 else { return }
		
		let viewRatio = viewWidth / viewHeight
		let imageRatio = image.size.width / image.size.height
		
		if imageRatio < viewRatio {
				// CASE: Image is "Taller" than the view (e.g., Portrait bird photo in a landscape card)
				// Behavior: Scale width to fit, align top, cut off bottom.
			
				// 1. Calculate how much we scaled the image down to fit the width
			let scale = viewWidth / image.size.width
			
				// 2. Calculate the "height" of the view in the coordinates of the original image
			let visibleHeightInImage = viewHeight / scale
			
				// 3. Normalize this (0.0 to 1.0) for the layer
			let normalizedHeight = visibleHeightInImage / image.size.height
			
				// 4. Set the rect: (x:0, y:0) is Top-Left. Width is full (1.0). Height is the calculated portion.
			coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: normalizedHeight)
			
		} else {
				// CASE: Image is "Wider" or equal (e.g., Panorama)
				// Behavior: Standard AspectFill (Center alignment) is usually preferred here,
				// but you can reset it to default (0,0,1,1) to be safe.
			coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
		}
	}
	override func layoutSubviews() {
		super.layoutSubviews()
			// We call this here to ensure it updates if the cell size changes (e.g. rotation)
        updateCardAppearance()
		alignImageTop()
	}
	
}
