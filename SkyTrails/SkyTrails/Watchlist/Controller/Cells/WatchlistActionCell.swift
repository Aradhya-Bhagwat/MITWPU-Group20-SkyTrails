import UIKit

class WatchlistActionCell: UICollectionViewCell {
	
	static let identifier = "WatchlistActionCell"
    private var defaultSystemBackgroundColor: UIColor = .white
	@IBOutlet weak var systemBackgroundView: UIView!
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var iconImageView: UIImageView!
	@IBOutlet weak var titleLabel: UILabel!
	override func awakeFromNib() {
		super.awakeFromNib()
        defaultSystemBackgroundColor = systemBackgroundView.backgroundColor ?? .white
		setupStyling()
	}
	func configure(icon: String, title: String, color: UIColor) {
		iconImageView.image = UIImage(named: icon)
		iconImageView.tintColor = color
		titleLabel.text = title
		titleLabel.textColor = color
		containerView.backgroundColor = color.withAlphaComponent(0.15)
	}
	private func setupStyling() {
		systemBackgroundView.layer.masksToBounds = false
        updateAppearanceForCurrentTrait()
		containerView.layer.cornerRadius = 16
		containerView.layer.masksToBounds = true
		self.layer.cornerRadius = 16
		self.layer.masksToBounds = false
		iconImageView.contentMode = .scaleAspectFit
		iconImageView.tintColor = .systemBlue
		titleLabel.font = .preferredFont(forTextStyle: .subheadline)
		titleLabel.adjustsFontForContentSizeCategory = true
		titleLabel.textAlignment = .center
		titleLabel.numberOfLines = 2
	}

    private func updateAppearanceForCurrentTrait() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        systemBackgroundView.backgroundColor = isDarkMode ? .secondarySystemBackground : defaultSystemBackgroundColor
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = isDarkMode ? 0 : 0.08
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 8
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateAppearanceForCurrentTrait()
    }
}
