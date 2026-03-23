import UIKit

final class WatchlistShapeCollectionViewCell: UICollectionViewCell {
	@IBOutlet private weak var iconImageView: UIImageView!
	@IBOutlet private weak var titleLabel: UILabel!

	func configure(shape: BirdShape) {
		iconImageView.image = UIImage(named: shape.icon)
		titleLabel.text = shape.name
	}
}
