	//
	//  BirdSmartCell.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 28/11/25.
	//

import UIKit

class BirdSmartCell: UITableViewCell {
	
	static let identifier = "BirdSmartCell"
    private var defaultContainerBackgroundColor: UIColor?
	
		// MARK: - IBOutlets
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var birdImageView: UIImageView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var locationLabel: UILabel!
	
	@IBOutlet var avatarImageViews: [UIImageView]!
	@IBOutlet weak var overflowBadgeView: UIView!
	@IBOutlet weak var overflowLabel: UILabel!
	@IBOutlet weak var avatarStackView: UIStackView!
	
	var shouldShowAvatars: Bool = true {
		didSet {
			avatarStackView.isHidden = !shouldShowAvatars
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
        defaultContainerBackgroundColor = containerView.backgroundColor
		setupUI()
	}
	
	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
	}
	
	private func setupUI() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
			// Container Styling
		containerView.layer.cornerRadius = 12
        containerView.backgroundColor = isDarkMode ? .secondarySystemBackground : defaultContainerBackgroundColor
		
			// Image Styling
		birdImageView.layer.cornerRadius = 12
		birdImageView.clipsToBounds = true
		birdImageView.contentMode = .scaleAspectFill
		birdImageView.backgroundColor = .systemGray5
		
			// Text Styling
		titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
		titleLabel.textColor = .label
		
		dateLabel.font = .systemFont(ofSize: 13, weight: .medium)
		dateLabel.textColor = .secondaryLabel
		
		locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
		locationLabel.textColor = .secondaryLabel
		
			// Configur avatar image views
		avatarImageViews.forEach {
			$0.layer.cornerRadius = 15
			$0.clipsToBounds = true
			$0.layer.borderWidth = 2
			$0.layer.borderColor = UIColor.white.cgColor
		}
		
			// Configure overflow badge
		overflowBadgeView.layer.cornerRadius = 15
		overflowBadgeView.clipsToBounds = true
		overflowBadgeView.layer.borderWidth = 2
		overflowBadgeView.layer.borderColor = UIColor.white.cgColor
		overflowBadgeView.backgroundColor = .systemGray
		overflowLabel.textColor = .white
		overflowLabel.font = .systemFont(ofSize: 12, weight: .bold)
		overflowLabel.textAlignment = .center
	}
	
	func configure(with entry: WatchlistEntry) {
		guard let bird = entry.bird else { return }
		titleLabel.text = bird.name
		
			// ---------------------------------------------------------------------------
			// Image — three-tier resolution:
			//   1. User-captured photo persisted to applicationSupportDirectory
			//   2. Seeded / bundled asset (asset catalogue)
			//   3. System placeholder
			// ---------------------------------------------------------------------------
		birdImageView.image = BirdSmartCell.loadImage(for: entry)
		
			// Date
		if let observationDate = entry.observationDate {
			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			dateLabel.text = formatter.string(from: observationDate)
			dateLabel.isHidden = false
		} else {
			dateLabel.isHidden = true
		}
		
			// Location
		if let userLocation = entry.locationDisplayName, !userLocation.isEmpty {
			locationLabel.text = userLocation
			locationLabel.isHidden = false
		} else if let locationName = bird.validLocations?.first {
			locationLabel.text = locationName
			locationLabel.isHidden = false
		} else {
			locationLabel.isHidden = true
		}
		
			// Avatars
		if shouldShowAvatars {
			let avatarImages: [String] = entry.observedBy != nil ? [entry.observedBy!] : []
			setupAvatars(images: avatarImages)
		} else {
			avatarStackView.isHidden = true
			avatarImageViews.forEach { $0.isHidden = true }
			overflowBadgeView.isHidden = true
		}
	}
	
	func configure(with bird: Bird) {
		titleLabel.text = bird.name
		
			// No entry available here — asset catalogue is the only source
		birdImageView.image = UIImage(named: bird.staticImageName) ?? UIImage(systemName: "photo")
		
		dateLabel.isHidden = true
		
		if let locationName = bird.validLocations?.first {
			locationLabel.text = locationName
			locationLabel.isHidden = false
		} else {
			locationLabel.isHidden = true
		}
		
		avatarStackView.isHidden = true
		avatarImageViews.forEach { $0.isHidden = true }
		overflowBadgeView.isHidden = true
	}
	
		// MARK: - Image Resolution Helper
	
		/// Resolves the best available image for an entry.
		/// Priority: user-captured photo on disk → bundled asset → system placeholder.
	private static func loadImage(for entry: WatchlistEntry) -> UIImage {
			// 1. Check for a user-captured photo saved to the app's support directory
		if let photoPath = entry.photos?.first?.imagePath {
			let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
			let fileURL = supportDir.appendingPathComponent(photoPath)
			if let image = UIImage(contentsOfFile: fileURL.path) {
				return image
			}
		}
		
			// 2. Fall back to the bundled / seeded asset catalogue image
		if let bird = entry.bird, let asset = UIImage(named: bird.staticImageName) {
			return asset
		}
		
			// 3. Generic placeholder
		return UIImage(systemName: "photo")!
	}
	
	private func setupAvatars(images: [String]) {
		avatarImageViews.forEach { $0.isHidden = true }
		overflowBadgeView.isHidden = true
		
		guard !images.isEmpty else {
			avatarStackView.isHidden = true
			return
		}
		avatarStackView.isHidden = false
		
		let limit = avatarImageViews.count
		let displayCount = min(images.count, limit)
		
		for i in 0..<displayCount {
			let imgView = avatarImageViews[i]
			imgView.isHidden = false
			let name = images[i]
			if let sys = UIImage(systemName: name) {
				imgView.image = sys.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
			} else {
				imgView.image = UIImage(named: name)
			}
		}
		
		if images.count > limit {
			overflowBadgeView.isHidden = false
			overflowLabel.text = "+\(images.count - limit)"
		}
	}
}
