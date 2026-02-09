import UIKit

class WatchlistActionCell: UICollectionViewCell {
	
	static let identifier = "WatchlistActionCell"
	
	// MARK: - Outlets
	@IBOutlet weak var systemBackgroundView: UIView!
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var iconImageView: UIImageView!
	@IBOutlet weak var titleLabel: UILabel!
	
	// MARK: - Lifecycle
	override func awakeFromNib() {
		super.awakeFromNib()
		setupStyling()
	}
	
	// MARK: - Configuration
	func configure(icon: String, title: String, color: UIColor) {
		iconImageView.image = UIImage(named: icon)
		iconImageView.tintColor = color
		titleLabel.text = title
		titleLabel.textColor = color
		containerView.backgroundColor = color.withAlphaComponent(0.15)
	}
	
	// MARK: - Styling
	private func setupStyling() {
		// System background view - shadow and corner radius are set in XIB via userDefinedRuntimeAttributes
		systemBackgroundView.layer.masksToBounds = false
		
		// Container view (inner layer with color)
		containerView.layer.cornerRadius = 16
		containerView.layer.masksToBounds = true
		self.layer.cornerRadius = 16
		self.layer.shadowColor = UIColor.black.cgColor
		self.layer.shadowOpacity = 0.08
		self.layer.shadowOffset = CGSize(width: 0, height: 4)
		self.layer.shadowRadius = 8
		self.layer.masksToBounds = false
		// Icon styling
		iconImageView.contentMode = .scaleAspectFit
		iconImageView.tintColor = .systemBlue
		
		// Label styling
		titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
		titleLabel.textAlignment = .center
		titleLabel.numberOfLines = 2
	}
}
