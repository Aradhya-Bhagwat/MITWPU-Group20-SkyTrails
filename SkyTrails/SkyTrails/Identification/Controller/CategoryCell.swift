import UIKit

class CategoryCell: UICollectionViewCell {
	@IBOutlet weak var iconImageView: UIImageView!
		// @IBOutlet weak var nameLabel: UILabel! // Optional if you want text below
	
    override func layoutSubviews() {
         super.layoutSubviews()
         // Ensure correct radius after Auto Layout
         contentView.layer.cornerRadius = contentView.bounds.width / 2
     }

     override var isSelected: Bool {
         didSet {
             updateAppearance()
         }
     }

     func configure(name: String, iconName: String, isSelected: Bool) {
         iconImageView.image = UIImage(named: iconName) ?? UIImage(named: "id_icn_field_marks")
         self.isSelected = isSelected
         updateAppearance()
     }

     private func updateAppearance() {
         if isSelected {
             contentView.layer.borderWidth = 3
             contentView.layer.borderColor = UIColor.systemBlue.cgColor
             contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
         } else {
             contentView.layer.borderWidth = 1
             contentView.layer.borderColor = UIColor.systemGray4.cgColor
             contentView.backgroundColor = .white
         }
     }
	
	
	
	
}
