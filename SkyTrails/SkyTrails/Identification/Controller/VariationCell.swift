import UIKit


class VariationCell: UICollectionViewCell {
	@IBOutlet weak var variationImageView: UIImageView!

    private var isSelectedCell = false

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.width / 2
        updateAppearance()
    }

    func configure(image: UIImage?, isSelected: Bool) {
        guard let imageView = variationImageView else {
            print("Critical: variationImageView is not connected in Storyboard!")
            return
        }

        imageView.image = image ?? UIImage(named: "id_icn_field_marks")
        imageView.tintColor = .label
        isSelectedCell = isSelected
        updateAppearance()
    }

    private func updateAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let unselectedColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        let selectedColor: UIColor = UIColor.systemBlue.withAlphaComponent(isDarkMode ? 0.24 : 0.10)
        let borderColor: UIColor = isDarkMode ? .systemGray3 : .systemGray
        let borderWidth: CGFloat = isDarkMode ? 1 : 1

        layer.masksToBounds = true
        backgroundColor = isSelectedCell ? selectedColor : unselectedColor
        layer.borderWidth = isSelectedCell ? 2 : borderWidth
        layer.borderColor = isSelectedCell ? UIColor.systemBlue.cgColor : borderColor.cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        updateAppearance()
    }
}
