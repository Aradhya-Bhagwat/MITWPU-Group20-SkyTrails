
import UIKit

enum WatchlistImageLoader {
    static func previewImage(named imageName: String) -> UIImage? {
        loadUserPhoto(named: imageName) ?? UIImage(named: imageName)
    }

    @MainActor
    static func image(named imageName: String) async -> UIImage? {
        if let userPhoto = loadUserPhoto(named: imageName) {
            return userPhoto
        }

        if let assetImage = UIImage(named: imageName) {
            return await IdentificationImageService.shared.image(for: imageName, shapeId: nil) ?? assetImage
        }

        return await IdentificationImageService.shared.image(for: imageName, shapeId: nil)
    }

    private static func loadUserPhoto(named imageName: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDirectory = documentsPath.appendingPathComponent("ObservedBirdPhotos")
        let imagePath = photosDirectory.appendingPathComponent(imageName)

        return UIImage(contentsOfFile: imagePath.path)
    }
}

class CustomWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "CustomWatchlistCollectionViewCell"
    private var defaultCoverOverImageBackgroundColor: UIColor?
    private var imageLoadTask: Task<Void, Never>?
    private var currentImageName: String?
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
        setupInteractions()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        currentImageName = nil
        coverImageView.image = nil
        coverImageView.backgroundColor = .systemGray5
        coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    
    private func setupInteractions() {
        leftBadgeView.isUserInteractionEnabled = true
        rightBadgeView.isUserInteractionEnabled = true
        
        let leftTap = UITapGestureRecognizer(target: self, action: #selector(didTapLeftBadge))
        leftBadgeView.addGestureRecognizer(leftTap)
        
        let rightTap = UITapGestureRecognizer(target: self, action: #selector(didTapRightBadge))
        rightBadgeView.addGestureRecognizer(rightTap)
    }
    
    @objc private func didTapLeftBadge() {
        showBadgeInfo(
            title: "Birds to Observe",
            message: "The green icon shows how many species in this watchlist are still unobserved."
        )
    }
    
    @objc private func didTapRightBadge() {
        showBadgeInfo(
            title: "Birds Spotted",
            message: "The blue icon shows how many species from this watchlist you have already successfully spotted!"
        )
    }
    
    private func showBadgeInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        
        if let vc = self.window?.rootViewController {
            let topVC = getTopViewController(from: vc)
            topVC.present(alert, animated: true)
        }
    }
    
    private func getTopViewController(from viewController: UIViewController) -> UIViewController {
        if let nav = viewController as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController ?? nav)
        } else if let tab = viewController as? UITabBarController {
            return getTopViewController(from: tab.selectedViewController ?? tab)
        } else if let presented = viewController.presentedViewController {
            return getTopViewController(from: presented)
        }
        return viewController
    }
    
    private func setupUI() {
        updateCardAppearance()
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = false
        coverImageView.layer.cornerRadius = 16
        coverImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coverImageView.clipsToBounds = true
        coverImageView.contentMode = .scaleAspectFill
        coverOverImageView.layer.cornerRadius = 16
        setupBadge(leftBadgeView, label: leftBadgeLabel, color: .systemGreen, cornerRadius: 8)
        setupBadge(rightBadgeView, label: rightBadgeLabel, color: .systemBlue, cornerRadius: 8)
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
        if !dto.subtitle.isEmpty {
            locationLabel.addIcon(text: dto.subtitle, iconName: "location.fill")
            locationLabel.isHidden = false
        } else {
            locationLabel.isHidden = true
        }
        if !dto.dateText.isEmpty {
            dateLabel.addIcon(text: dto.dateText, iconName: "calendar")
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }
        leftBadgeLabel.addIcon(text: "\(dto.stats.unobservedCount)", iconName: "bird")
        rightBadgeLabel.addIcon(text: "\(dto.stats.observedCount)", iconName: "bird.fill")
        configureCoverImage(named: dto.image)
    }

    private func configureCoverImage(named imageName: String?) {
        imageLoadTask?.cancel()
        currentImageName = imageName
        coverImageView.backgroundColor = .systemGray5
        coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)

        guard let imageName, !imageName.isEmpty else {
            coverImageView.image = nil
            return
        }

        if let previewImage = WatchlistImageLoader.previewImage(named: imageName) {
            coverImageView.image = previewImage
            alignImageTop()
        } else {
            coverImageView.image = nil
        }

        imageLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let resolvedImage = await WatchlistImageLoader.image(named: imageName)
            guard !Task.isCancelled, self.currentImageName == imageName else { return }

            self.coverImageView.image = resolvedImage
            self.coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)

            if resolvedImage != nil {
                self.alignImageTop()
            }
        }
    }
    
    private func isDateValid(start: Date, end: Date) -> Bool {
        return start != end
    }
	
	private func alignImageTop() {
		guard let image = coverImageView.image else { return }
		
		let viewWidth = coverImageView.bounds.width
		let viewHeight = coverImageView.bounds.height
		guard viewWidth > 0, viewHeight > 0, image.size.width > 0, image.size.height > 0 else { return }
		
		let viewRatio = viewWidth / viewHeight
		let imageRatio = image.size.width / image.size.height
		
		if imageRatio < viewRatio {
			let scale = viewWidth / image.size.width
			let visibleHeightInImage = viewHeight / scale
			let normalizedHeight = visibleHeightInImage / image.size.height
			coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: normalizedHeight)
			
		} else {
			coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
		}
	}
	override func layoutSubviews() {
		super.layoutSubviews()
        updateCardAppearance()
		alignImageTop()
	}
	
}
