import UIKit

class CategoryCell: UICollectionViewCell {
    @IBOutlet weak var iconImageView: UIImageView!

    private var isSelectedCell = false
    private var imageTask: Task<Void, Never>?
    private var representedIconKey: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
    }

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
        representedIconKey = iconName
        let fallback = UIImage(named: iconName) ?? UIImage(named: "id_icn_field_marks")
        iconImageView.image = fallback
        iconImageView.tintColor = .label
        iconImageView.accessibilityLabel = name
        self.isSelected = isSelected
        updateAppearance()

        imageTask?.cancel()
        imageTask = Task { [weak self] in
            let loaded = await IdentificationImageService.shared.image(for: iconName, shapeId: nil)
            guard !Task.isCancelled else { return }
            guard let self, self.representedIconKey == iconName else { return }
            self.iconImageView.image = loaded ?? fallback
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        representedIconKey = nil
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

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        updateAppearance()
    }
}
