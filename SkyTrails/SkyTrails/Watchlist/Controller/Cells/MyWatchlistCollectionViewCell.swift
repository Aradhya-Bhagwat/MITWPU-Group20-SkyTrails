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
	
	@IBOutlet weak var mainContainerView: UIView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var image1: UIImageView!
	@IBOutlet weak var image2: UIImageView!
	@IBOutlet weak var stackContainerView: UIView!
	@IBOutlet weak var stackFrontImage: UIImageView!
	@IBOutlet weak var stackBackImage: UIImageView!
	@IBOutlet weak var speciesContainer: UIView!
	@IBOutlet weak var speciesCountLabel: UILabel!
	@IBOutlet weak var speciesIcon: UIImageView!
	@IBOutlet weak var speciesTitleLabel: UILabel!
	
	@IBOutlet weak var observedContainer: UIView!
	@IBOutlet weak var observedCountLabel: UILabel!
	@IBOutlet weak var observedIcon: UIImageView!
	@IBOutlet weak var observedTitleLabel: UILabel!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setupStyling()
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		image1.image = nil
		image2.image = nil
		stackFrontImage.image = nil
		stackBackImage.image = nil
		stackContainerView.isHidden = true
		stackBackImage.isHidden = true
		stackBackImage.subviews.forEach { $0.removeFromSuperview() }
	}
	
	func configure(with data: WatchlistData) {
		titleLabel.text = "All my birds"
        let unobservedCount = data.totalCount - data.observedCount
		speciesCountLabel.text = "\(unobservedCount)"
        speciesTitleLabel.text = "Unobserved"
        
		observedCountLabel.text = "\(data.observedCount)"
		
		let images = data.images
		if images.indices.contains(0) {
			image1.isHidden = false
			image1.image = images[0]
			image1.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
			alignImageTop(image1)
		} else {
			image1.isHidden = true
		}
		if images.indices.contains(1) {
			image2.isHidden = false
			image2.image = images[1]
			image2.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
			alignImageTop(image2)
		} else {
			image2.isHidden = true
		}
		if images.indices.contains(2) {
			stackContainerView.isHidden = false
			stackFrontImage.image = images[2]
			stackFrontImage.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
			alignImageTop(stackFrontImage)
			let hasMoreContent = data.totalImageCount > 3
			
			if hasMoreContent {
				stackBackImage.isHidden = false
				let backImg = images.indices.contains(3) ? images[3] : images[2]
				stackBackImage.image = backImg
				stackBackImage.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
				alignImageTop(stackBackImage)
				
				addBlurToBackImage()
			} else {
				stackBackImage.isHidden = true
			}
		} else {
			stackContainerView.isHidden = true
		}
	}

	private func alignImageTop(_ imageView: UIImageView) {
		guard let image = imageView.image else { return }

		let viewWidth = imageView.bounds.width
		let viewHeight = imageView.bounds.height
		guard viewWidth > 0, viewHeight > 0, image.size.width > 0, image.size.height > 0 else { return }

		let viewRatio = viewWidth / viewHeight
		let imageRatio = image.size.width / image.size.height

		if imageRatio < viewRatio {
			let scale = viewWidth / image.size.width
			let visibleHeightInImage = viewHeight / scale
			let normalizedHeight = visibleHeightInImage / image.size.height
			imageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: normalizedHeight)

		} else {
			imageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
		}
	}
	
	private func setupStyling() {
		self.contentView.layer.cornerRadius = 22
		self.contentView.layer.masksToBounds = true
		
		mainContainerView.backgroundColor = .secondarySystemGroupedBackground
		mainContainerView.layer.cornerRadius = 22
		mainContainerView.layer.masksToBounds = true
		self.layer.shadowColor = UIColor.black.cgColor
		self.layer.shadowOpacity = 0.08
		self.layer.shadowOffset = CGSize(width: 0, height: 4)
		self.layer.shadowRadius = 8
		self.layer.masksToBounds = false
		let imageRadius: CGFloat = 12
		let images = [image1, image2, stackFrontImage, stackBackImage]
		
		images.forEach { imageView in
			imageView?.layer.cornerRadius = imageRadius
			imageView?.layer.cornerCurve = .continuous
			imageView?.clipsToBounds = true
			imageView?.contentMode = .scaleAspectFill
		}
		speciesContainer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
		speciesContainer.layer.cornerRadius = 8
		speciesContainer.layer.masksToBounds = true
		
		speciesCountLabel.textColor = .systemGreen
		speciesIcon.tintColor = .systemGreen
		speciesTitleLabel.textColor = .systemGreen
		observedContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
		observedContainer.layer.cornerRadius = 8
		observedContainer.layer.masksToBounds = true
		
		observedCountLabel.textColor = .systemBlue
		observedIcon.tintColor = .systemBlue
		observedTitleLabel.textColor = .systemBlue
	}
	
	private func addBlurToBackImage() {
		stackBackImage.subviews.forEach { $0.removeFromSuperview() }
		
		let blurEffect = UIBlurEffect(style: .regular)
		let blurView = UIVisualEffectView(effect: blurEffect)
		
		blurView.frame = stackBackImage.bounds
		blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		blurView.alpha = 0.5
		
		stackBackImage.addSubview(blurView)
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		alignImageTop(image1)
		alignImageTop(image2)
		alignImageTop(stackFrontImage)
		alignImageTop(stackBackImage)
	}
}
