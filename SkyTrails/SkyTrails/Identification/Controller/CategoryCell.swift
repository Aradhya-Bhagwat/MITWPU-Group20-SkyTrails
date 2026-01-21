import UIKit

class CategoryCell: UICollectionViewCell {
	@IBOutlet weak var iconImageView: UIImageView!
		// @IBOutlet weak var nameLabel: UILabel! // Optional if you want text below
	
	override var isSelected: Bool {
		didSet {
			updateAppearance()
		}
	}
	
	func configure(name: String, iconName: String, isSelected: Bool) {
		iconImageView.image = UIImage(named: iconName) ?? UIImage(named: "id_icn_field_marks")

	}
	
	private func updateAppearance() {
		if isSelected {
			iconImageView.layer.borderWidth = 3
			iconImageView.layer.borderColor = UIColor.systemBlue.cgColor
			iconImageView.layer.cornerRadius = iconImageView.frame.width / 2
			iconImageView.alpha = 1.0
		} else {
			iconImageView.layer.borderWidth = 0
			iconImageView.alpha = 0.5 // Dimmed when not selected
		}
	}
}
