
import UIKit

class BirdSmartCell: UITableViewCell {
	
	static let identifier = "BirdSmartCell"
    private var defaultContainerBackgroundColor: UIColor?
    private var imageLoadTask: Task<Void, Never>?
    private var currentImageKey: String?
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

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        currentImageKey = nil
        birdImageView.image = UIImage(systemName: "photo")
        birdImageView.backgroundColor = .systemGray5
    }
	
	private func setupUI() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
		containerView.layer.cornerRadius = 12
        containerView.backgroundColor = isDarkMode ? .secondarySystemBackground : defaultContainerBackgroundColor
		birdImageView.layer.cornerRadius = 12
		birdImageView.clipsToBounds = true
		birdImageView.contentMode = .scaleAspectFill
		birdImageView.backgroundColor = .systemGray5
		titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
		titleLabel.textColor = .label
		
		dateLabel.font = .systemFont(ofSize: 13, weight: .medium)
		dateLabel.textColor = .secondaryLabel
		
		locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
		locationLabel.textColor = .secondaryLabel
		avatarImageViews.forEach {
			$0.layer.cornerRadius = 15
			$0.clipsToBounds = true
			$0.layer.borderWidth = 2
			$0.layer.borderColor = UIColor.white.cgColor
		}
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
        configureBirdImage(primaryImageName: entry.photos?.first?.imagePath, fallbackImageName: bird.staticImageName)
		if let observationDate = entry.observationDate {
			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			dateLabel.text = formatter.string(from: observationDate)
			dateLabel.isHidden = false
		} else {
			dateLabel.isHidden = true
		}
		if let userLocation = entry.locationDisplayName, !userLocation.isEmpty {
			locationLabel.text = userLocation
			locationLabel.isHidden = false
		} else if let likelySpot = bird.likelySpot {
			locationLabel.text = likelySpot
			locationLabel.isHidden = false
		} else {
			locationLabel.isHidden = true
		}
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
        configureBirdImage(primaryImageName: nil, fallbackImageName: bird.staticImageName)
		
		dateLabel.isHidden = true
		
		if let likelySpot = bird.likelySpot {
			locationLabel.text = likelySpot
			locationLabel.isHidden = false
		} else {
			locationLabel.isHidden = true
		}
		
		avatarStackView.isHidden = true
		avatarImageViews.forEach { $0.isHidden = true }
		overflowBadgeView.isHidden = true
	}

    private func configureBirdImage(primaryImageName: String?, fallbackImageName: String) {
        imageLoadTask?.cancel()

        let imageKey = primaryImageName ?? fallbackImageName
        currentImageKey = imageKey
        birdImageView.backgroundColor = .systemGray5
        birdImageView.image = WatchlistImageLoader.previewImage(named: imageKey)
            ?? WatchlistImageLoader.previewImage(named: fallbackImageName)
            ?? UIImage(systemName: "photo")

        imageLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let resolvedImage = await self.resolveImage(primaryImageName: primaryImageName, fallbackImageName: fallbackImageName)
            guard !Task.isCancelled, self.currentImageKey == imageKey else { return }

            self.birdImageView.image = resolvedImage ?? UIImage(systemName: "photo")
        }
    }

    private func resolveImage(primaryImageName: String?, fallbackImageName: String) async -> UIImage? {
        if let primaryImageName,
           let primaryImage = await WatchlistImageLoader.image(named: primaryImageName) {
            return primaryImage
        }

        return await WatchlistImageLoader.image(named: fallbackImageName)
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
