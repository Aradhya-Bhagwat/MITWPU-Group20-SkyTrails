
import UIKit

class shapeCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var shapeImageView: UIImageView!
    
    @IBOutlet weak var shapeNameLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        shapeNameLabel.font = .preferredFont(forTextStyle: .caption1)
        shapeNameLabel.adjustsFontForContentSizeCategory = true
    }
	func configure(with shapeName: String, imageName: String) {
		shapeNameLabel.text = shapeName
		shapeImageView.image = UIImage(named: imageName)
	}

}
