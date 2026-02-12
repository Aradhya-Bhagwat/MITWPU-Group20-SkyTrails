import UIKit

class CategoryCell: UICollectionViewCell {
    @IBOutlet weak var iconImageView: UIImageView!

    private var isSelectedCell = false

    override var isSelected: Bool {
        didSet {
            isSelectedCell = isSelected
            updateAppearance()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.width / 2
        updateAppearance()
    }

    func configure(name: String, iconName: String, isSelected: Bool) {
        iconImageView.image = UIImage(named: iconName) ?? UIImage(named: "id_icn_field_marks")
        iconImageView.tintColor = .label
        self.isSelected = isSelected
        updateAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isSelectedCell = false
        isSelected = false
        updateAppearance()
    }

    private func updateAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let unselectedColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        let selectedColor: UIColor = UIColor.systemBlue.withAlphaComponent(isDarkMode ? 0.24 : 0.10)
        let borderColor: UIColor = isDarkMode ? .systemGray3 : .systemGray4
        let borderWidth: CGFloat = isDarkMode ? 1 : 1

        layer.masksToBounds = true
        backgroundColor = isSelectedCell ? selectedColor : unselectedColor
        layer.borderWidth = isSelectedCell ? 3 : borderWidth
        layer.borderColor = isSelectedCell ? UIColor.systemBlue.cgColor : borderColor.cgColor
        iconImageView.tintColor = .label
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        updateAppearance()
    }
}
