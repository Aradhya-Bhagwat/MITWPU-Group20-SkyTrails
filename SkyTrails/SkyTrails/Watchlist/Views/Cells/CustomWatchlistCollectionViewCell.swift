	//
	//  CustomWatchlistCollectionViewCell.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 26/11/25.
	//

import UIKit

class CustomWatchlistCollectionViewCell: UICollectionViewCell {
	
	static let identifier = "CustomWatchlistCollectionViewCell"
	
		// MARK: - IBOutlets
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var coverImageView: UIImageView!
	
		// NOTE: This outlet is connected to the UIView (viewOverImage)
		// that creates the white background and the curved seam overlap.
	@IBOutlet weak var coverOverImageView: UIView! // Type is UIView for content background
	
		// Stack Views
	@IBOutlet weak var labelsStackView: UIStackView! // Connect to "MasterVerticalStack"
	
		// Labels
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var locationLabel: UILabel!
	
		// Badges
	@IBOutlet weak var leftBadgeView: UIView!    // Green Badge View (Left)
	@IBOutlet weak var leftBadgeLabel: UILabel!
	
	@IBOutlet weak var rightBadgeView: UIView!   // Blue Badge View (Right)
	@IBOutlet weak var rightBadgeLabel: UILabel!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setupUI()
		
			// Disable clipping on the cell itself and its content view to allow shadows to show
		self.clipsToBounds = false
		self.contentView.clipsToBounds = false
	}
	
	private func setupUI() {
			// 1. Container Styling (Outer Card with Shadow)
		let cardColor = UIColor.secondarySystemGroupedBackground // Matches default white/light gray background
		containerView.backgroundColor = cardColor
		containerView.layer.cornerRadius = 16
		containerView.layer.shadowColor = UIColor.black.cgColor
		containerView.layer.shadowOpacity = 0.1
		containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
		containerView.layer.shadowRadius = 6
		containerView.layer.masksToBounds = false
		
			// 2. Image Styling (The Bird Photo)
		coverImageView.layer.cornerRadius = 16
		coverImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
		coverImageView.clipsToBounds = true
		coverImageView.contentMode = .scaleAspectFill
		
			// 3. The Content Overlap View (viewOverImage)
			// CRITICAL: Set its background color in XIB to match the card color (white).
		coverOverImageView.layer.cornerRadius = 16
			// We want ALL corners to be rounded:
			// - Top corners: To create the curved overlap effect over the image.
			// - Bottom corners: To match the container's rounded bottom corners.
			// So we do NOT limit maskedCorners.
		
			// 4. Badge Styling
			// Green Badge (Left) -> Watchlist Total
		setupBadge(leftBadgeView, label: leftBadgeLabel, color: .systemGreen, cornerRadius: 8)
			// Blue Badge (Right) -> Observed Count
		setupBadge(rightBadgeView, label: rightBadgeLabel, color: .systemBlue, cornerRadius: 8)
		
			// 5. Text Styling

		titleLabel.textColor = .label
		
		[dateLabel, locationLabel].forEach {
			$0?.font = .systemFont(ofSize: 13, weight: .medium)
			$0?.textColor = .secondaryLabel
		}
	}
	
	private func setupBadge(_ view: UIView, label: UILabel, color: UIColor, cornerRadius: CGFloat) {
		view.layer.cornerRadius = cornerRadius
		view.backgroundColor = color.withAlphaComponent(0.15)
		view.layer.masksToBounds = true
		label.textColor = color
		label.font = .systemFont(ofSize: 12, weight: .bold)
	}
	
	func configure(with watchlist: Watchlist) {
		titleLabel.text = watchlist.title
		
			// ---------------------------------------------------------
			// MARK: Date & Location Logic
			// ---------------------------------------------------------
		
			// Configure Location (Icon: Location Pin)
		addIconToLabel(label: locationLabel, text: watchlist.location, iconName: "location.fill")
		
			// Configure Date (Icon: Calendar)
		if isDateValid(start: watchlist.startDate, end: watchlist.endDate) {
			let formatter = DateFormatter()
			formatter.dateFormat = "d MMM"
			
			let startStr = formatter.string(from: watchlist.startDate)
			let endStr = formatter.string(from: watchlist.endDate)
			let dateString = "\(startStr) - \(endStr)"
			
			addIconToLabel(label: dateLabel, text: dateString, iconName: "calendar")
			dateLabel.isHidden = false
		} else {
				// Hides the label, causing locationLabel to slide up
			dateLabel.isHidden = true
		}
		
			// ---------------------------------------------------------
			// MARK: Badge Logic (Data Swap Implemented)
			// ---------------------------------------------------------
		
			// Left Badge (Green) -> Watchlist Total (Icon: Leaf/Sprout)
		addIconToLabel(label: leftBadgeLabel,
					   text: "\(watchlist.birds.count)",
					   iconName: "bird")
		
			// Right Badge (Blue) -> Observed Count (Icon: Flying Bird)
		addIconToLabel(label: rightBadgeLabel,
					   text: "\(watchlist.observedCount)",
					   iconName: "bird.fill")
		
			// ---------------------------------------------------------
			// MARK: Cover Image
			// ---------------------------------------------------------
		if let firstBird = watchlist.birds.first, let imageName = firstBird.images.first {
			coverImageView.image = UIImage(named: imageName)
		} else {
			coverImageView.image = nil
			coverImageView.backgroundColor = .systemGray5
		}
	}
	
		// MARK: - Helpers
	
	private func isDateValid(start: Date, end: Date) -> Bool {
		return start != end
	}
	
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
