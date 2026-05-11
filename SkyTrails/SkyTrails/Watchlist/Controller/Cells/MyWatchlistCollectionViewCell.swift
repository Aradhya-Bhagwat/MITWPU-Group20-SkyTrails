
import UIKit

struct WatchlistData {
	let title: String
	let unobservedImages: [UIImage]
	let observedImages: [UIImage]
	let totalCount: Int
	let observedCount: Int
	
	init(title: String, unobservedImages: [UIImage], observedImages: [UIImage], totalCount: Int, observedCount: Int) {
		self.title = title
		self.unobservedImages = unobservedImages
		self.observedImages = observedImages
		self.totalCount = totalCount
		self.observedCount = observedCount
	}
}

class MyWatchlistCollectionViewCell: UICollectionViewCell {
	
	static let identifier = "MyWatchlistCollectionViewCell"
	
	@IBOutlet weak var mainContainerView: UIView!
	@IBOutlet weak var image1: UIImageView!
	@IBOutlet weak var image2: UIImageView!
    @IBOutlet weak var imageStackView: UIStackView!
    @IBOutlet weak var contentStackView: UIStackView!
	
	@IBOutlet weak var speciesContainer: UIView!
	@IBOutlet weak var speciesCountLabel: UILabel!
	@IBOutlet weak var speciesIcon: UIImageView!
	@IBOutlet weak var speciesTitleLabel: UILabel!
	
	@IBOutlet weak var observedContainer: UIView!
	@IBOutlet weak var observedCountLabel: UILabel!
	@IBOutlet weak var observedIcon: UIImageView!
	@IBOutlet weak var observedTitleLabel: UILabel!
    
    private var emptyStateContainer: UIView!
    private var emptyMessageLabel: UILabel!
    
    private var unobservedPlaceholderLabel: UILabel!
    private var observedPlaceholderLabel: UILabel!
    
    private var unobservedImages: [UIImage] = []
    private var observedImages: [UIImage] = []
    
    private var unobservedTimer: Timer?
    private var observedTimer: Timer?
    
    private var currentUnobservedIndex = 0
    private var currentObservedIndex = 0
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setupStyling()
        setupEmptyStateView()
        setupSlotPlaceholders()
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		image1.image = nil
		image2.image = nil
        stopSlideshows()
        unobservedImages = []
        observedImages = []
	}
    
    private func setupSlotPlaceholders() {
        unobservedPlaceholderLabel = createPlaceholderLabel(text: "Add species you want to see them here")
        observedPlaceholderLabel = createPlaceholderLabel(text: "Log your sightings to build your observed gallery")
        
        insertPlaceholder(unobservedPlaceholderLabel, behind: image1)
        insertPlaceholder(observedPlaceholderLabel, behind: image2)
    }
    
    private func createPlaceholderLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }
    
    private func insertPlaceholder(_ label: UILabel, behind imageView: UIImageView) {
        imageView.superview?.insertSubview(label, belowSubview: imageView)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
        ])
    }
    
    private func setupEmptyStateView() {
        emptyStateContainer = UIView()
        emptyStateContainer.translatesAutoresizingMaskIntoConstraints = false
        emptyStateContainer.isHidden = true
        
        emptyMessageLabel = UILabel()
        emptyMessageLabel.numberOfLines = 0
        emptyMessageLabel.textAlignment = .center
        emptyMessageLabel.textColor = .secondaryLabel
        emptyMessageLabel.font = .systemFont(ofSize: 17, weight: .medium)
        emptyMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyMessageLabel.text = "Add a bird to your watchlist to begin your birding journey!"
        
        emptyStateContainer.addSubview(emptyMessageLabel)
        
        NSLayoutConstraint.activate([
            emptyMessageLabel.centerXAnchor.constraint(equalTo: emptyStateContainer.centerXAnchor),
            emptyMessageLabel.centerYAnchor.constraint(equalTo: emptyStateContainer.centerYAnchor),
            emptyMessageLabel.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor, constant: 32),
            emptyMessageLabel.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor, constant: -32)
        ])
        
        contentStackView.insertArrangedSubview(emptyStateContainer, at: 0)
    }
	
    // MARK: - Enhanced Configuration (Uses ViewModel)
    
    /// Configure cell with pre-loaded ViewModel (NO BUSINESS LOGIC)
    func configure(with viewModel: WatchlistCellViewModel) {
        speciesCountLabel.text = "\(viewModel.unobservedCount)"
        speciesTitleLabel.text = "To observe"
        observedCountLabel.text = "\(viewModel.observedCount)"
        
        self.unobservedImages = viewModel.unobservedImages
        self.observedImages = viewModel.observedImages
        
        if unobservedImages.isEmpty && observedImages.isEmpty {
            imageStackView.isHidden = true
            emptyStateContainer.isHidden = false
            stopSlideshows()
        } else {
            imageStackView.isHidden = false
            emptyStateContainer.isHidden = true
            
            configureSlot(imageView: image1, placeholder: unobservedPlaceholderLabel, images: unobservedImages)
            configureSlot(imageView: image2, placeholder: observedPlaceholderLabel, images: observedImages)
            
            startSlideshows()
        }
    }
    
    // MARK: - Legacy Configuration (Kept for backward compatibility)
    
	func configure(with data: WatchlistData) {
        let unobservedCount = data.totalCount - data.observedCount
		speciesCountLabel.text = "\(unobservedCount)"
        speciesTitleLabel.text = "To observe"
		observedCountLabel.text = "\(data.observedCount)"
		
		self.unobservedImages = data.unobservedImages
        self.observedImages = data.observedImages
        
        if unobservedImages.isEmpty && observedImages.isEmpty {
            imageStackView.isHidden = true
            emptyStateContainer.isHidden = false
            stopSlideshows()
        } else {
            imageStackView.isHidden = false
            emptyStateContainer.isHidden = true
            
            configureSlot(imageView: image1, placeholder: unobservedPlaceholderLabel, images: unobservedImages)
            configureSlot(imageView: image2, placeholder: observedPlaceholderLabel, images: observedImages)
            
            startSlideshows()
        }
	}
    
    private func configureSlot(imageView: UIImageView, placeholder: UILabel, images: [UIImage]) {
        imageView.isHidden = false
        if images.isEmpty {
            placeholder.isHidden = false
            imageView.image = nil
            imageView.backgroundColor = .secondarySystemFill.withAlphaComponent(0.05)
        } else {
            placeholder.isHidden = true
            imageView.image = images[0]
            imageView.backgroundColor = .clear
            alignImageTop(imageView)
        }
    }

    private func startSlideshows() {
        stopSlideshows()
        
        if unobservedImages.count > 1 {
            currentUnobservedIndex = 1
            unobservedTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { [weak self] _ in
                self?.cycleUnobserved()
            }
        }
        
        if observedImages.count > 1 {
            currentObservedIndex = 1
            observedTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.cycleObserved()
            }
        }
    }
    
    private func stopSlideshows() {
        unobservedTimer?.invalidate()
        unobservedTimer = nil
        observedTimer?.invalidate()
        observedTimer = nil
    }
    
    private func cycleUnobserved() {
        guard unobservedImages.count > 1 else { return }
        if currentUnobservedIndex >= unobservedImages.count {
            currentUnobservedIndex = 0
        }
        
        let nextImage = unobservedImages[currentUnobservedIndex]
        UIView.transition(with: image1, duration: 1.0, options: .transitionCrossDissolve, animations: {
            self.image1.image = nextImage
            self.alignImageTop(self.image1)
        }, completion: nil)
        
        currentUnobservedIndex += 1
    }
    
    private func cycleObserved() {
        guard observedImages.count > 1 else { return }
        if currentObservedIndex >= observedImages.count {
            currentObservedIndex = 0
        }
        
        let nextImage = observedImages[currentObservedIndex]
        UIView.transition(with: image2, duration: 1.0, options: .transitionCrossDissolve, animations: {
            self.image2.image = nextImage
            self.alignImageTop(self.image2)
        }, completion: nil)
        
        currentObservedIndex += 1
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
		self.contentView.layer.cornerRadius = 24
		self.contentView.layer.masksToBounds = true
		
		mainContainerView.backgroundColor = .secondarySystemGroupedBackground
		mainContainerView.layer.cornerRadius = 24
		mainContainerView.layer.masksToBounds = true
		self.layer.shadowColor = UIColor.black.cgColor
		self.layer.shadowOpacity = 0.06
		self.layer.shadowOffset = CGSize(width: 0, height: 2)
		self.layer.shadowRadius = 10
		self.layer.masksToBounds = false
		
		let images = [image1, image2]
		
		images.forEach { imageView in
			imageView?.layer.cornerRadius = 16
			imageView?.layer.cornerCurve = .continuous
			imageView?.clipsToBounds = true
			imageView?.contentMode = .scaleAspectFill
		}
		speciesContainer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
		speciesContainer.layer.cornerRadius = 12
		speciesContainer.layer.masksToBounds = true
		
		speciesCountLabel.textColor = .systemGreen
		speciesIcon.tintColor = .systemGreen
		speciesIcon.image = UIImage(systemName: "bird")
		speciesTitleLabel.textColor = .systemGreen
        speciesCountLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        
		observedContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
		observedContainer.layer.cornerRadius = 12
		observedContainer.layer.masksToBounds = true
		
		observedCountLabel.textColor = .systemBlue
		observedIcon.tintColor = .systemBlue
		observedIcon.image = UIImage(systemName: "bird.fill")
		observedTitleLabel.textColor = .systemBlue
        observedCountLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        
        [speciesTitleLabel, observedTitleLabel].forEach {
            $0?.font = .systemFont(ofSize: 14, weight: .medium)
        }
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		alignImageTop(image1)
		alignImageTop(image2)
	}
}
