import UIKit


class VariationCell: UICollectionViewCell {
	@IBOutlet weak var variationImageView: UIImageView!
	
	func configure(image: UIImage?, isSelected: Bool) {
			// 1. SAFETY CHECK: Ensure the outlet is connected before using it
		guard let imageView = variationImageView else {
			print("⚠️ Critical: variationImageView is not connected in Storyboard!")
			return
		}
		
		imageView.image = image ?? UIImage(named: "id_icn_field_marks")
		
			
		variationImageView.contentMode = .scaleAspectFit
		layer.cornerRadius = frame.width / 2
		
		if isSelected {
			layer.borderWidth = 2
			layer.borderColor = UIColor.systemBlue.cgColor
			backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
		} else {
			layer.borderWidth = 1
			layer.borderColor = UIColor.systemGray5.cgColor
			backgroundColor = .white
		}
	}
}

