
import UIKit

class SharedWatchlistCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "SharedWatchlistCollectionViewCell"
    private var defaultContainerBackgroundColor: UIColor = .white
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var mainImageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var greenBadgeView: UIView!
    @IBOutlet weak var greenBadgeLabel: UILabel!
    @IBOutlet weak var blueBadgeView: UIView!
    @IBOutlet weak var blueBadgeLabel: UILabel!
    
    @IBOutlet weak var avatarStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        defaultContainerBackgroundColor = containerView.backgroundColor ?? .white
        setupUI()
    }
    
    private func setupUI() {
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false

        updateCardAppearance()
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = false
        mainImageView.layer.cornerRadius = 16
        mainImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        mainImageView.clipsToBounds = true
        mainImageView.contentMode = .scaleAspectFill
        setupBadge(greenBadgeView, label: greenBadgeLabel, color: .systemGreen)
        setupBadge(blueBadgeView, label: blueBadgeLabel, color: .systemBlue)
        dateLabel.textColor = .secondaryLabel
        locationLabel.textColor = .secondaryLabel
    }

    private func updateCardAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        containerView.backgroundColor = isDarkMode ? .secondarySystemBackground : defaultContainerBackgroundColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = isDarkMode ? 0 : 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
    }
    
    private func setupBadge(_ view: UIView, label: UILabel, color: UIColor) {
        view.backgroundColor = color.withAlphaComponent(0.15)
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        
        label.textColor = color
        label.font = .systemFont(ofSize: 12, weight: .bold)
    }
    func configure(title: String,
                   location: String,
                   dateRange: String,
                   mainImage: UIImage?,
                   speciesCount: Int,
                   observedCount: Int,
                   userImages: [UIImage]) {
        updateCardAppearance()
        
        titleLabel.text = title
        self.mainImageView.image = mainImage

        if !location.isEmpty {
            locationLabel.addIcon(text: location, iconName: "location.fill")
            locationLabel.isHidden = false
        } else {
            locationLabel.isHidden = true
        }
        if !dateRange.isEmpty {
            dateLabel.addIcon(text: dateRange, iconName: "calendar")
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }

        greenBadgeLabel.addIcon(text: "\(speciesCount)", iconName: "bird")
        blueBadgeLabel.addIcon(text: "\(observedCount)", iconName: "bird.fill")
        
        setupAvatars(images: userImages)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardAppearance()
    }
    
    private func setupAvatars(images: [UIImage]) {
        avatarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let maxDisplay = 3
        let imageSize: CGFloat = 30
        
        let shouldShowCountBadge = images.count > maxDisplay
        let displayCount = shouldShowCountBadge ? maxDisplay - 1 : images.count
        
        for i in 0..<displayCount {
            let imageView = UIImageView(image: images[i])
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = imageSize / 2
            imageView.clipsToBounds = true
            imageView.layer.borderWidth = 2
            imageView.layer.borderColor = UIColor.white.cgColor
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
            
            avatarStackView.addArrangedSubview(imageView)
        }
        
        if shouldShowCountBadge {
            let remaining = images.count - displayCount
            let badgeLabel = UILabel()
            badgeLabel.text = "+\(remaining)"
            badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
            badgeLabel.textColor = .white
            badgeLabel.textAlignment = .center
            
            let badgeView = UIView()
            badgeView.backgroundColor = UIColor.systemGray
            badgeView.layer.cornerRadius = imageSize / 2
            badgeView.clipsToBounds = true
            badgeView.layer.borderWidth = 2
            badgeView.layer.borderColor = UIColor.white.cgColor
            
            badgeView.addSubview(badgeLabel)
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false


            badgeView.translatesAutoresizingMaskIntoConstraints = false
            badgeView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
            badgeView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
            
            avatarStackView.addArrangedSubview(badgeView)
        }
    }
}
