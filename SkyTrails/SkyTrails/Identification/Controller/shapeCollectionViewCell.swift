
import UIKit

class shapeCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var shapeImageView: UIImageView!
    
    @IBOutlet weak var shapeNameLabel: UILabel!
    private var imageLoadTask: Task<Void, Never>?

    override func awakeFromNib() {
        super.awakeFromNib()
        shapeNameLabel.font = .preferredFont(forTextStyle: .caption1)
        shapeNameLabel.adjustsFontForContentSizeCategory = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        shapeImageView.image = nil
        shapeNameLabel.text = nil
    }

	func configure(with shapeName: String, imageName: String) {
		shapeNameLabel.text = shapeName
        shapeImageView.image = IdentificationImageService.shared.cachedImage(for: imageName)

        imageLoadTask?.cancel()
        imageLoadTask = Task { [weak self] in
            guard let self else { return }
            let image = await IdentificationImageService.shared.image(for: imageName, shapeId: nil)
            guard !Task.isCancelled else { return }
            self.shapeImageView.image = image
        }
	}

}
