
import UIKit

final class WatchlitEmptyCollectionViewCell: UICollectionViewCell {

	static let identifier = "WatchlitEmptyCollectionViewCell"

	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var emptyImageView: UIImageView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var subtitleLabel: UILabel!

	override func awakeFromNib() {
		super.awakeFromNib()
		setupUI()
	}

	private func setupUI() {
		containerView.layer.cornerRadius = 20
		containerView.layer.borderWidth = 1
		containerView.layer.borderColor = UIColor.systemGray5.cgColor
		containerView.backgroundColor = .secondarySystemGroupedBackground
		containerView.layer.masksToBounds = true

		emptyImageView.contentMode = .scaleAspectFit
		emptyImageView.clipsToBounds = true

		titleLabel.font = .preferredFont(forTextStyle: .title1)
		titleLabel.adjustsFontForContentSizeCategory = true
		titleLabel.textColor = .label
		titleLabel.numberOfLines = 2
		titleLabel.adjustsFontSizeToFitWidth = false
		titleLabel.minimumScaleFactor = 1.0

		subtitleLabel.font = .preferredFont(forTextStyle: .body)
		subtitleLabel.adjustsFontForContentSizeCategory = true
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.numberOfLines = 2
		subtitleLabel.adjustsFontSizeToFitWidth = false
		subtitleLabel.minimumScaleFactor = 1.0
	}

	func configure(imageName: String, title: String, subtitle: String) {
		titleLabel.text = title
		subtitleLabel.text = subtitle
		emptyImageView.image = UIImage(named: imageName) ?? UIImage(named: imageName + " ")
	}
}
