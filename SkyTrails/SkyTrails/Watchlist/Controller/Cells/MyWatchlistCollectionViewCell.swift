
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
    private var allImages: [UIImage] = []
    private var slideshowTimer: Timer?
    private var currentImageIndex = 0
    private var activeSlot = 0 // 0 for image1, 1 for image2
	
	override func awakeFromNib() {
		super.awakeFromNib()
		setupStyling()
        setupEmptyStateView()
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		image1.image = nil
		image2.image = nil
        stopSlideshow()
        allImages = []
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
        emptyMessageLabel.text = "The skies are waiting.\nAdd a bird to your collection to begin your trail."
        
        emptyStateContainer.addSubview(emptyMessageLabel)
        
        NSLayoutConstraint.activate([
            emptyMessageLabel.centerXAnchor.constraint(equalTo: emptyStateContainer.centerXAnchor),
            emptyMessageLabel.centerYAnchor.constraint(equalTo: emptyStateContainer.centerYAnchor),
            emptyMessageLabel.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor, constant: 32),
            emptyMessageLabel.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor, constant: -32)
        ])
        
        // Insert into content stack at the top
        contentStackView.insertArrangedSubview(emptyStateContainer, at: 0)
    }
	
	func configure(with data: WatchlistData) {
        let unobservedCount = data.totalCount - data.observedCount
		speciesCountLabel.text = "\(unobservedCount)"
        speciesTitleLabel.text = "Unobserved"
		observedCountLabel.text = "\(data.observedCount)"
		
		self.allImages = data.images
        
        if allImages.isEmpty {
            imageStackView.isHidden = true
            emptyStateContainer.isHidden = false
            stopSlideshow()
        } else {
            imageStackView.isHidden = false
            emptyStateContainer.isHidden = true
            
            if allImages.count == 1 {
                // Show only one image, filling the entire stack view
                image1.isHidden = false
                image2.isHidden = true
                image1.image = allImages[0]
                alignImageTop(image1)
                stopSlideshow()
            } else {
                // Initial setup for two images
                image1.isHidden = false
                image2.isHidden = false
                image1.image = allImages[0]
                image2.image = allImages[1]
                alignImageTop(image1)
                alignImageTop(image2)
                
                if allImages.count > 2 {
                    currentImageIndex = 2
                    startSlideshow()
                } else {
                    stopSlideshow()
                }
            }
        }
	}

    private func startSlideshow() {
        stopSlideshow()
        guard allImages.count > 2 else { return }
        
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.cycleImage()
        }
    }
    
    private func stopSlideshow() {
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
    
    private func cycleImage() {
        guard allImages.count > 2 else { return }
        if currentImageIndex >= allImages.count {
            currentImageIndex = 0
        }
        
        let nextImage = allImages[currentImageIndex]
        let slotToUpdate = activeSlot == 0 ? image1 : image2
        
        UIView.transition(with: slotToUpdate!, duration: 1.0, options: .transitionCrossDissolve, animations: {
            slotToUpdate?.image = nextImage
            self.alignImageTop(slotToUpdate!)
        }, completion: nil)
        
        activeSlot = (activeSlot + 1) % 2
        currentImageIndex += 1
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
