import UIKit

struct WatchlistData {
	let title: String
	let images: [UIImage]
	let totalCount: Int
	let observedCount: Int
	let totalImageCount: Int
	
	init(title: String, images: [UIImage], totalCount: Int, observedCount: Int, totalImageCount: Int? = nil) {
		self.title = title
		self.images = images
		self.totalCount = totalCount
		self.observedCount = observedCount
		self.totalImageCount = totalImageCount ?? images.count
	}
}

class MyWatchlistCollectionViewCell: UICollectionViewCell {
	
	static let identifier = "MyWatchlistCollectionViewCell"
	
		// MARK: - Outlets
	
	@IBOutlet weak var mainContainerView: UIView!
	@IBOutlet weak var titleLabel: UILabel!
	
		// --- Image Row ---
	
		// First two slots
	@IBOutlet weak var image1: UIImageView!
	@IBOutlet weak var image2: UIImageView!
	
		// Slot 3: The Stack Container
	@IBOutlet weak var stackContainerView: UIView!
	
		// Inside Slot 3
	@IBOutlet weak var stackFrontImage: UIImageView! // The clear one in front
	@IBOutlet weak var stackBackImage: UIImageView!  // The blurred one behind
	
		// --- Stats Row ---
	@IBOutlet weak var speciesContainer: UIView!
	@IBOutlet weak var speciesCountLabel: UILabel!
	@IBOutlet weak var speciesIcon: UIImageView!
	@IBOutlet weak var speciesTitleLabel: UILabel!
	
	@IBOutlet weak var observedContainer: UIView!
	@IBOutlet weak var observedCountLabel: UILabel!
	@IBOutlet weak var observedIcon: UIImageView!
	@IBOutlet weak var observedTitleLabel: UILabel!
	
		// MARK: - Lifecycle
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setupStyling()
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
			// Clear data to prevent reuse glitches
		image1.image = nil
		image2.image = nil
		stackFrontImage.image = nil
		stackBackImage.image = nil
		
			// Hide stack by default
		stackContainerView.isHidden = true
		stackBackImage.isHidden = true
		
			// Remove old blur effects
		stackBackImage.subviews.forEach { $0.removeFromSuperview() }
	}
	
		// MARK: - Configuration
	
	func configure(with data: WatchlistData) {
		titleLabel.text = "All my birds"
		
        // Updated to show Unobserved instead of Total
        let unobservedCount = data.totalCount - data.observedCount
		speciesCountLabel.text = "\(unobservedCount)"
        speciesTitleLabel.text = "Unobserved"
        
		observedCountLabel.text = "\(data.observedCount)"
		
		let images = data.images
		
			// 1. Configure First Image
		if images.indices.contains(0) {
			image1.isHidden = false
			image1.image = images[0]
		} else {
			image1.isHidden = true
		}
		
			// 2. Configure Second Image
		if images.indices.contains(1) {
			image2.isHidden = false
			image2.image = images[1]
		} else {
			image2.isHidden = true
		}
		
			// 3. Configure Third Slot (The Stack)
		if images.indices.contains(2) {
			stackContainerView.isHidden = false
			stackFrontImage.image = images[2]
			
				// Determine if we need the "depth" effect (back image)
				// We show it if there are more than 3 images in total
			let hasMoreContent = data.totalImageCount > 3
			
			if hasMoreContent {
				stackBackImage.isHidden = false
				
					// If we have a 4th image, use it for the background.
					// If not, just reuse the 3rd image to create the visual bulk.
				let backImg = images.indices.contains(3) ? images[3] : images[2]
				stackBackImage.image = backImg
				
				addBlurToBackImage()
			} else {
				stackBackImage.isHidden = true
			}
		} else {
			stackContainerView.isHidden = true
		}
	}
	
		// MARK: - Styling
	
	private func setupStyling() {
			// Main Card Styling
		self.contentView.layer.cornerRadius = 22
		self.contentView.layer.masksToBounds = true
		
		mainContainerView.backgroundColor = .secondarySystemGroupedBackground
		mainContainerView.layer.cornerRadius = 22
		mainContainerView.layer.masksToBounds = true
		
			// Card Shadow (Applied to self, not contentView)
		self.layer.shadowColor = UIColor.black.cgColor
		self.layer.shadowOpacity = 0.08
		self.layer.shadowOffset = CGSize(width: 0, height: 4)
		self.layer.shadowRadius = 8
		self.layer.masksToBounds = false
		
			// Image Corner Radius (Squircles)
		let imageRadius: CGFloat = 12
		let images = [image1, image2, stackFrontImage, stackBackImage]
		
		images.forEach { imageView in
			imageView?.layer.cornerRadius = imageRadius
			imageView?.layer.cornerCurve = .continuous
			imageView?.clipsToBounds = true
			imageView?.contentMode = .scaleAspectFill
		}
		
			// --- Stats Pills Styling ---
		
			// 1. Species Container (Green background, opacity 0.15)
		speciesContainer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
		speciesContainer.layer.cornerRadius = 8
		speciesContainer.layer.masksToBounds = true
		
		speciesCountLabel.textColor = .systemGreen
		speciesIcon.tintColor = .systemGreen
		speciesTitleLabel.textColor = .systemGreen
		
			// 2. Observed Container (Blue background, opacity 0.15)
		observedContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
		observedContainer.layer.cornerRadius = 8
		observedContainer.layer.masksToBounds = true
		
		observedCountLabel.textColor = .systemBlue
		observedIcon.tintColor = .systemBlue
		observedTitleLabel.textColor = .systemBlue
	}
	
	private func addBlurToBackImage() {
			// Ensure we don't double add blurs
		stackBackImage.subviews.forEach { $0.removeFromSuperview() }
		
		let blurEffect = UIBlurEffect(style: .regular)
		let blurView = UIVisualEffectView(effect: blurEffect)
		
		blurView.frame = stackBackImage.bounds
		blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		blurView.alpha = 0.5 // Adjust opacity to control how "faded" it looks
		
		stackBackImage.addSubview(blurView)
	}
}
