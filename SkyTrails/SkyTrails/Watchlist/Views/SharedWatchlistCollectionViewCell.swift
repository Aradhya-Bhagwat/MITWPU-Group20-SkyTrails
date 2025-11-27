//
//  SharedWatchlistCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

	//
	//  SharedWatchlistCollectionViewCell.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 27/11/25.
	//



class SharedWatchlistCollectionViewCell: UICollectionViewCell {
	
	static let identifier = "SharedWatchlistCollectionViewCell"
	
		// MARK: - IBOutlets
	
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var mainImageView: UIImageView!
	
		// Labels
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var locationLabel: UILabel!
	
		// Badges (Left side of bottom bar)
	@IBOutlet weak var greenBadgeView: UIView!
	@IBOutlet weak var greenBadgeLabel: UILabel!
	@IBOutlet weak var blueBadgeView: UIView!
	@IBOutlet weak var blueBadgeLabel: UILabel!
	
		// Avatar Stack (Right side of bottom bar)
	@IBOutlet weak var avatarStackView: UIStackView!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setupUI()
	}
	
	private func setupUI() {
			// 1. Container Styling
		self.clipsToBounds = false
		self.contentView.clipsToBounds = false
		
		containerView.backgroundColor = .white
		containerView.layer.cornerRadius = 16
		containerView.layer.shadowColor = UIColor.black.cgColor
		containerView.layer.shadowOpacity = 0.1
		containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
		containerView.layer.shadowRadius = 8
		containerView.layer.masksToBounds = false
		
			// 2. Main Image Styling
			// Rounds only the top-left and bottom-left corners to match the card
		mainImageView.layer.cornerRadius = 16
		mainImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
		mainImageView.clipsToBounds = true
		mainImageView.contentMode = .scaleAspectFill
		
			// 3. Badge Styling (Pastel backgrounds)
		setupBadge(greenBadgeView, label: greenBadgeLabel, color: .systemGreen)
		setupBadge(blueBadgeView, label: blueBadgeLabel, color: .systemBlue)
		
			// 4. Label Styling
		titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
		dateLabel.textColor = .secondaryLabel
		locationLabel.textColor = .secondaryLabel
	}
	
	private func setupBadge(_ view: UIView, label: UILabel, color: UIColor) {
		view.backgroundColor = color.withAlphaComponent(0.15)
		view.layer.cornerRadius = 8
		view.layer.masksToBounds = true
		
		label.textColor = color
		label.font = .systemFont(ofSize: 12, weight: .bold)
	}
	
		// MARK: - Configuration
	
		/// Configures the cell with data.
		/// - Parameters:
		///   - title: The name of the watchlist.
		///   - location: Location string.
		///   - dateRange: Date string (e.g. "8th Oct - 7th Nov").
		///   - mainImage: The cover image for the watchlist.
		///   - stats: Tuple containing (greenCount, blueCount).
		///   - userImages: Array of user profile images.
	func configure(title: String,
				   location: String,
				   dateRange: String,
				   mainImage: UIImage?,
				   stats: (Int, Int),
				   userImages: [UIImage]) {
		
		titleLabel.text = title
		self.mainImageView.image = mainImage
		
			// 1. Configure Labels with Icons
		addIconToLabel(label: locationLabel, text: location, iconName: "location.fill")
		addIconToLabel(label: dateLabel, text: dateRange, iconName: "calendar")
		
			// 2. Configure Badges
		addIconToLabel(label: greenBadgeLabel, text: "\(stats.0)", iconName: "bird")
		addIconToLabel(label: blueBadgeLabel, text: "\(stats.1)", iconName: "bird.fill")
		
			// 3. Configure Avatars
		setupAvatars(images: userImages)
	}
	
		// MARK: - Avatar Logic
	
	private func setupAvatars(images: [UIImage]) {
			// Clear existing views from the stack
		avatarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
		
		let maxDisplay = 3 // Maximum number of circles to show
		let imageSize: CGFloat = 30 // Size of the circles
		
			// If we have more images than the max, we show (max-1) images and one "+X" badge
		let shouldShowCountBadge = images.count > maxDisplay
		let displayCount = shouldShowCountBadge ? maxDisplay - 1 : images.count
		
			// 1. Add User Images
		for i in 0..<displayCount {
			let imageView = UIImageView(image: images[i])
			imageView.contentMode = .scaleAspectFill
			imageView.layer.cornerRadius = imageSize / 2
			imageView.clipsToBounds = true
			
				// White border for separation effect
			imageView.layer.borderWidth = 2
			imageView.layer.borderColor = UIColor.white.cgColor
			
				// Constraint for size
			imageView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
			imageView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
			
			avatarStackView.addArrangedSubview(imageView)
		}
		
			// 2. Add "+X" Badge if needed
		if shouldShowCountBadge {
			let remaining = images.count - displayCount
			let badgeLabel = UILabel()
			badgeLabel.text = "+\(remaining)"
			badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
			badgeLabel.textColor = .white
			badgeLabel.textAlignment = .center
			
			let badgeView = UIView()
			badgeView.backgroundColor = UIColor.systemGray // or a brand color
			badgeView.layer.cornerRadius = imageSize / 2
			badgeView.clipsToBounds = true
			
				// Border
			badgeView.layer.borderWidth = 2
			badgeView.layer.borderColor = UIColor.white.cgColor
			
				// Layout Label inside Badge
			badgeView.addSubview(badgeLabel)
			badgeLabel.translatesAutoresizingMaskIntoConstraints = false
			NSLayoutConstraint.activate([
				badgeLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
				badgeLabel.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor)
			])
			
				// Size constraints
			badgeView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
			badgeView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
			
			avatarStackView.addArrangedSubview(badgeView)
		}
	}
	
		// MARK: - Helpers (Copied for consistency)
	
	private func addIconToLabel(label: UILabel, text: String, iconName: String) {
		let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
		let image = UIImage(systemName: iconName, withConfiguration: config)?
			.withTintColor(label.textColor, renderingMode: .alwaysOriginal)
		
		guard let safeImage = image else {
			label.text = text
			return
		}
		
		let attachment = NSTextAttachment(image: safeImage)
			// Adjust yOffset to center the icon vertically with text
		let yOffset = (label.font.capHeight - safeImage.size.height).rounded() / 2
		attachment.bounds = CGRect(x: 0, y: yOffset - 1, width: safeImage.size.width, height: safeImage.size.height)
		
		let attrString = NSMutableAttributedString(attachment: attachment)
		attrString.append(NSAttributedString(string: "  " + text))
		
		label.attributedText = attrString
	}
}
