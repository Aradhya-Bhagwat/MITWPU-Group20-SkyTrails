
import UIKit

class CustomWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "CustomWatchlistCollectionViewCell"
    private var defaultCoverOverImageBackgroundColor: UIColor?
    private var hasCoverImage = false
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
            message: "The green icon shows the total number of species included in this watchlist for you to discover."
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
        if hasCoverImage {
            coverOverImageView.backgroundColor = isDarkMode ? .secondarySystemBackground : defaultCoverOverImageBackgroundColor
        } else {
            coverOverImageView.backgroundColor = .clear
        }
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
    
    // MARK: - Enhanced Configuration (Uses ViewModel - NO LOGIC)
    
    /// Configure cell with pre-loaded ViewModel (pure display)
    func configure(with viewModel: CustomWatchlistCellViewModel) {
        updateCardAppearance()
        titleLabel.text = viewModel.title
        
        if !viewModel.subtitle.isEmpty {
            locationLabel.addIcon(text: viewModel.subtitle, iconName: "location.fill")
            locationLabel.isHidden = false
        } else {
            locationLabel.isHidden = true
        }
        
        if !viewModel.dateText.isEmpty {
            dateLabel.addIcon(text: viewModel.dateText, iconName: "calendar")
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }
        
        leftBadgeLabel.addIcon(text: "\(viewModel.totalCount)", iconName: "bird")
        rightBadgeLabel.addIcon(text: "\(viewModel.observedCount)", iconName: "bird.fill")
        
        // Set pre-loaded cover image
        if let coverImage = viewModel.coverImage {
            hasCoverImage = true
            coverImageView.image = coverImage
            coverImageView.backgroundColor = .clear
            coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            alignImageTop()
        } else {
            hasCoverImage = false
            coverImageView.image = nil
            coverImageView.backgroundColor = .clear
            coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        updateCardAppearance()
    }
    
    // MARK: - Legacy Configuration (Kept for backward compatibility)
    
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
        leftBadgeLabel.addIcon(text: "\(dto.stats.totalCount)", iconName: "bird")
        rightBadgeLabel.addIcon(text: "\(dto.stats.observedCount)", iconName: "bird.fill")
        if let imageName = dto.image {
            if let userPhoto = loadUserPhoto(named: imageName) {
                hasCoverImage = true
                coverImageView.image = userPhoto
                coverImageView.backgroundColor = .clear
                coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                alignImageTop()
            } 
            else if let assetImage = UIImage(named: imageName) {
                hasCoverImage = true
                coverImageView.image = assetImage
                coverImageView.backgroundColor = .clear
                Task { @MainActor in
                    if let supabaseImage = await IdentificationImageService.shared.image(for: imageName, shapeId: nil) {
                        self.hasCoverImage = true
                        self.coverImageView.image = supabaseImage
                        self.coverImageView.backgroundColor = .clear
                        self.coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                        self.alignImageTop()
                        self.updateCardAppearance()
                    }
                }
            } else {
                hasCoverImage = false
                coverImageView.image = nil
                coverImageView.backgroundColor = .clear
                Task { @MainActor in
                    if let image = await IdentificationImageService.shared.image(for: imageName, shapeId: nil) {
                        self.hasCoverImage = true
                        self.coverImageView.image = image
                        self.coverImageView.backgroundColor = .clear
                        self.coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                        self.alignImageTop()
                        self.updateCardAppearance()
                    }
                }
            }
        } else {
            hasCoverImage = false
            coverImageView.image = nil
            coverImageView.backgroundColor = .clear
            coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        updateCardAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hasCoverImage = false
        coverImageView.image = nil
        coverImageView.backgroundColor = .clear
        coverImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        updateCardAppearance()
    }
    
    private func loadUserPhoto(named imageName: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDirectory = documentsPath.appendingPathComponent("ObservedBirdPhotos")
        let imagePath = photosDirectory.appendingPathComponent(imageName)
        
        return UIImage(contentsOfFile: imagePath.path)
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
