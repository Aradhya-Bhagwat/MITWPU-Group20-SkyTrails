
import UIKit

class BirdSmartCell: UITableViewCell {
	
	static let identifier = "BirdSmartCell"
    private var defaultContainerBackgroundColor: UIColor?
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
	
    // MARK: - Enhanced Configuration (Uses ViewModel - NO LOGIC)
    
    /// Configure cell with pre-loaded ViewModel (pure display, no I/O, no logic)
    func configure(with viewModel: BirdEntryCellViewModel) {
        titleLabel.text = viewModel.birdName
        birdImageView.image = viewModel.birdImage  // Pre-loaded image
        
        if let date = viewModel.observationDate {
            dateLabel.text = date
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }
        
        if let location = viewModel.location, !location.isEmpty {
            locationLabel.text = location
            locationLabel.isHidden = false
        } else {
            locationLabel.isHidden = true
        }
        
        if viewModel.shouldShowAvatars {
            setupAvatars(images: viewModel.avatarNames)
        } else {
            avatarStackView.isHidden = true
            avatarImageViews.forEach { $0.isHidden = true }
            overflowBadgeView.isHidden = true
        }
    }
    
    // MARK: - Legacy Configuration (Kept for backward compatibility)
    
	func configure(with entry: WatchlistEntry) {
		guard let bird = entry.bird else {
            #if DEBUG
            print("[BirdSmartCell] configure - ERROR: entry.bird is nil for entry ID: \(entry.id)")
            print("[BirdSmartCell] configure - Entry status: \(entry.status)")
            print("[BirdSmartCell] configure - Entry photos count: \(entry.photos?.count ?? 0)")
            #endif
            titleLabel.text = "Unknown"
            birdImageView.image = UIImage(systemName: "photo")
            return
        }
        
        #if DEBUG
        print("[BirdSmartCell] configure - Entry ID: \(entry.id)")
        print("[BirdSmartCell] configure - Bird name: '\(bird.name)'")
        print("[BirdSmartCell] configure - Bird staticImageName: '\(bird.staticImageName)'")
        print("[BirdSmartCell] configure - Bird bird_id: \(bird.bird_id)")
        print("[BirdSmartCell] configure - Entry status: \(entry.status)")
        print("[BirdSmartCell] configure - Entry photos count: \(entry.photos?.count ?? 0)")
        #endif
        
		titleLabel.text = bird.name
        
#if DEBUG
        print("[BirdSmartCell] Configuring for entry with bird '\(bird.name)', staticImageName: '\(bird.staticImageName)'")
#endif

		if let photoPath = entry.photos?.first?.imagePath {
#if DEBUG
            print("[BirdSmartCell] Found user photo path: \(photoPath)")
#endif
			let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
			let photoDir = documentsDir.appendingPathComponent("ObservedBirdPhotos", isDirectory: true)
			let fileURL = photoDir.appendingPathComponent(photoPath)
			if let diskImage = UIImage(contentsOfFile: fileURL.path) {
                #if DEBUG
                print("[BirdSmartCell] Successfully loaded user photo from disk")
                #endif
				birdImageView.image = diskImage
			} else if let assetImage = UIImage(named: bird.staticImageName) {
                #if DEBUG
                print("[BirdSmartCell] User photo not on disk, loaded from assets")
                #endif
				birdImageView.image = assetImage
			} else {
                #if DEBUG
                print("[BirdSmartCell] User photo not on disk, assets not found, using placeholder")
                #endif
				birdImageView.image = UIImage(systemName: "photo")
			}
		} else {
#if DEBUG
            print("[BirdSmartCell] No user photo, loading default/remote for '\(bird.staticImageName)'")
#endif
            // Try asset catalog first
            if let assetImage = UIImage(named: bird.staticImageName) {
                #if DEBUG
                print("[BirdSmartCell] Loaded bird image from assets")
                #endif
                birdImageView.image = assetImage
            } else {
                // Try documents directory (similar to UnobservedDetailViewController)
                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(bird.staticImageName)
                if let docImage = UIImage(contentsOfFile: fileURL.path) {
                    #if DEBUG
                    print("[BirdSmartCell] Loaded bird image from documents directory")
                    #endif
                    birdImageView.image = docImage
                } else {
                    #if DEBUG
                    print("[BirdSmartCell] No local bird image found, using placeholder temporarily")
                    #endif
                    birdImageView.image = UIImage(systemName: "photo")
                }
            }
            
            // Always try fetching remote
            Task { @MainActor in
                if let image = await IdentificationImageService.shared.image(for: bird.staticImageName, shapeId: nil) {
#if DEBUG
                    print("[BirdSmartCell] Successfully loaded remote image for '\(bird.staticImageName)'")
#endif
                    self.birdImageView.image = image
                } else {
#if DEBUG
                    print("[BirdSmartCell] Failed to load remote image for '\(bird.staticImageName)'")
#endif
                }
            }
		}
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
		birdImageView.image = UIImage(named: bird.staticImageName) ?? UIImage(systemName: "photo")
		Task { @MainActor in
			if let image = await IdentificationImageService.shared.image(for: bird.staticImageName, shapeId: nil) {
				self.birdImageView.image = image
			}
		}
		
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
	private func loadImage(for entry: WatchlistEntry) async -> UIImage {
		if let photoPath = entry.photos?.first?.imagePath {
			let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
			let photoDir = documentsDir.appendingPathComponent("ObservedBirdPhotos", isDirectory: true)
			let fileURL = photoDir.appendingPathComponent(photoPath)
			if let image = UIImage(contentsOfFile: fileURL.path) {
				return image
			}
		}
		if let bird = entry.bird, let image = await IdentificationImageService.shared.image(for: bird.staticImageName, shapeId: nil) {
			return image
		}
		if let bird = entry.bird, let asset = UIImage(named: bird.staticImageName) {
			return asset
		}
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
