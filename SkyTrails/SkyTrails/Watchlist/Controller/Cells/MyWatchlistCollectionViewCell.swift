import UIKit

class MyWatchlistCollectionViewCell: UICollectionViewCell {
	
		// MARK: - IBOutlets (matching XIB)
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var imageView1: UIImageView!
	@IBOutlet weak var imageView2: UIImageView!
	@IBOutlet weak var imageView3: UIImageView!
	@IBOutlet weak var deckContainerView: UIView!
	@IBOutlet weak var blurEffectView: UIVisualEffectView!
	@IBOutlet weak var greenBadgeView: UIView!
	@IBOutlet weak var blueBadgeView: UIView!
	@IBOutlet weak var greenCountLabel: UILabel!
	@IBOutlet weak var blueCountLabel: UILabel!
	
	@IBOutlet weak var speciesLabel: UILabel!
	@IBOutlet weak var observedLabel: UILabel!
		// MARK: - Constants
	 let reuseIdentifier = "MyWatchlistCollectionViewCell"
	
		// MARK: - Lifecycle
	override func awakeFromNib() {
		super.awakeFromNib()
		setupUI()
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		imageView1.image = nil
		imageView2.image = nil
		imageView3.image = nil
		greenCountLabel.text = ""
		blueCountLabel.text = ""
	}
	
		// MARK: - UI Setup
	private func setupUI() {
			// Container view styling
		containerView.backgroundColor = .white
		containerView.layer.cornerRadius = 16
		containerView.layer.shadowColor = UIColor.black.cgColor
		containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
		containerView.layer.shadowRadius = 8
		containerView.layer.shadowOpacity = 0.1
		containerView.layer.masksToBounds = false
		
			// Title label styling
		titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
		titleLabel.textColor = .black
		
			// Image views styling
		setupImageView(imageView1)
		setupImageView(imageView2)
		setupImageView(imageView3)
		
			// Deck container (third image with blur)
		deckContainerView.layer.cornerRadius = 16
		deckContainerView.clipsToBounds = true
		deckContainerView.backgroundColor = .systemGray6
		
			// MARK: - Green Section (Total/Species)
		greenBadgeView.backgroundColor = UIColor(red: 0.165, green: 0.643, blue: 0.263, alpha: 0.12)
		greenBadgeView.layer.cornerRadius = 16
		
		greenCountLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
		greenCountLabel.textColor = UIColor(red: 0.165, green: 0.643, blue: 0.263, alpha: 1.0)
		
			// New Species Label
		speciesLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
		speciesLabel.textColor = UIColor(red: 0.165, green: 0.643, blue: 0.263, alpha: 1.0)
		
			// MARK: - Blue Section (Observed)
			// Fixed: Added background color for blue badge
		blueBadgeView.backgroundColor = UIColor(red: 0.235, green: 0.329, blue: 0.918, alpha: 0.12)
		blueBadgeView.layer.cornerRadius = 16
		
		blueCountLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
		blueCountLabel.textColor = UIColor(red: 0.235, green: 0.329, blue: 0.918, alpha: 1.0)
		
			// New Observed Label
		observedLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
		observedLabel.textColor = UIColor(red: 0.235, green: 0.329, blue: 0.918, alpha: 1.0)
	}
	
	private func setupImageView(_ imageView: UIImageView) {
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.layer.cornerRadius = 16
		imageView.backgroundColor = .systemGray6
	}
	
		// MARK: - Configuration
	func configure(with data: WatchlistData) {
		titleLabel.text = data.title
		
			// Set images
		if data.images.indices.contains(0) {
			imageView1.image = data.images[0]
		}
		if data.images.indices.contains(1) {
			imageView2.image = data.images[1]
		}
		if data.images.indices.contains(2) {
			imageView3.image = data.images[2]
		}
		
			// Show blur effect if there are more than 3 images
		blurEffectView.isHidden = data.totalImageCount <= 3
		
			// Set badge counts
		greenCountLabel.text = "\(data.totalCount)"
		blueCountLabel.text = "\(data.observedCount)"
	}
	
		// MARK: - Cell Registration Helper
	static func register(in collectionView: UICollectionView) {
		let nib = UINib(nibName: String(describing: self), bundle: nil)
		collectionView.register(nib, forCellWithReuseIdentifier: reuseIdentifier)
	}
}

	// MARK: - Data Model
struct WatchlistData {
	let title: String
	let images: [UIImage]
	let totalCount: Int
	let observedCount: Int
	let totalImageCount: Int // Total number of images (used to determine if blur is needed)
	
	init(title: String, images: [UIImage], totalCount: Int, observedCount: Int, totalImageCount: Int? = nil) {
		self.title = title
		self.images = images
		self.totalCount = totalCount
		self.observedCount = observedCount
		self.totalImageCount = totalImageCount ?? images.count
	}
}

	// MARK: - UIView Extension for Shadow (matches XIB runtime

