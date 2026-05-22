import UIKit
import SwiftData

class HistoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var historyImageView: UIImageView!
    @IBOutlet weak var specieNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var speciesCapsuleView: UIView!
    
    @IBOutlet weak var containeView: UIView!
    private var imageTask: Task<Void, Never>?
    private var representedImageKey: String?
    
    private let gradientLayer = CAGradientLayer()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private var capsuleIconView: UIImageView?

    private func applySelectionAppearance() {
        updateCellUI(isSelected: isSelected)
    }

    private func updateCellUI(isSelected: Bool) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let unselectedColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        layer.cornerRadius = 20
        layer.masksToBounds = false
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true

        if isSelected {
            contentView.layer.borderWidth = 2
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
            contentView.backgroundColor = isDarkMode 
                ? UIColor.systemBlue.withAlphaComponent(0.15) 
                : UIColor.systemBlue.withAlphaComponent(0.06)
        } else {
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = isDarkMode 
                ? UIColor.white.withAlphaComponent(0.1).cgColor 
                : UIColor.label.withAlphaComponent(0.08).cgColor
            contentView.backgroundColor = unselectedColor
        }

        containeView.backgroundColor = contentView.backgroundColor
        
        speciesCapsuleView.backgroundColor = .clear
        speciesCapsuleView.layer.borderColor = isDarkMode 
            ? UIColor.white.withAlphaComponent(0.15).cgColor 
            : UIColor.label.withAlphaComponent(0.1).cgColor

        if isDarkMode {
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
            layer.shadowPath = nil
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.06
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 8
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
        contentView.clipsToBounds = true

        // Configure gradient
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor
        ]
        gradientLayer.locations = [0.55, 1.0]
        containeView.layer.insertSublayer(gradientLayer, below: speciesCapsuleView.layer)

        // Configure frosted glass capsule background
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        speciesCapsuleView.addSubview(blurView)

        // Remove speciesCapsuleView subviews and re-add in a StackView
        speciesCapsuleView.subviews.forEach { 
            if $0 !== blurView { $0.removeFromSuperview() }
        }

        let iconView = UIImageView(image: UIImage(systemName: "bird"))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        self.capsuleIconView = iconView

        specieNameLabel.translatesAutoresizingMaskIntoConstraints = false
        specieNameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        specieNameLabel.textColor = .label
        specieNameLabel.numberOfLines = 1
        specieNameLabel.lineBreakMode = .byTruncatingTail
        specieNameLabel.adjustsFontSizeToFitWidth = true
        specieNameLabel.minimumScaleFactor = 0.8

        let stackView = UIStackView(arrangedSubviews: [iconView, specieNameLabel])
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        blurView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -6)
        ])

        speciesCapsuleView.layer.cornerRadius = 14
        speciesCapsuleView.layer.borderWidth = 0.5
        speciesCapsuleView.clipsToBounds = true

        applySelectionAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        representedImageKey = nil
        historyImageView.image = nil
        specieNameLabel.text = nil
        dateLabel?.text = nil
       
        applySelectionAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = containeView.bounds
        blurView.frame = speciesCapsuleView.bounds
        applySelectionAppearance()
    }
    
    func configureCell(historyItem: IdentificationSession) {
        applySelectionAppearance()
        specieNameLabel.textAlignment = .natural
        specieNameLabel.textColor = .label
        
        if let bird = historyItem.result?.bird {
            specieNameLabel.text = bird.commonName
            capsuleIconView?.isHidden = false
            capsuleIconView?.image = UIImage(systemName: "bird")
            
            let imagePath = bird.imageUrl ?? bird.staticImageName
            representedImageKey = imagePath

            let fallbackImage = UIImage(named: imagePath)
            historyImageView.image = fallbackImage ?? UIImage(systemName: "bird.fill")
            historyImageView.tintColor = fallbackImage == nil ? .secondaryLabel : nil
            historyImageView.contentMode = fallbackImage == nil ? .scaleAspectFit : .scaleAspectFill

            imageTask?.cancel()
            imageTask = Task { [weak self] in
                let loaded = await IdentificationImageService.shared.image(for: imagePath, shapeId: nil)
                guard !Task.isCancelled else { return }
                guard let self, self.representedImageKey == imagePath else { return }
                if let loaded {
                    self.historyImageView.image = loaded
                    self.historyImageView.contentMode = .scaleAspectFill
                    self.historyImageView.tintColor = nil
                }
            }
        } else {
            specieNameLabel.text = "Unknown Species"
            capsuleIconView?.isHidden = false
            capsuleIconView?.image = UIImage(systemName: "questionmark.circle")
            
            historyImageView.image = UIImage(systemName: "questionmark.circle.fill")
            historyImageView.tintColor = .secondaryLabel
            historyImageView.contentMode = .scaleAspectFit
        }

        historyImageView.layer.cornerRadius = 0
        historyImageView.clipsToBounds = true
        dateLabel?.text = nil
    }
    
    func showEmptyState() {
        historyImageView.image = UIImage(systemName: "clock.arrow.circlepath")
        historyImageView.tintColor = .tertiaryLabel
        historyImageView.contentMode = .scaleAspectFit

        specieNameLabel.text = "No history yet"
        specieNameLabel.textAlignment = .center
        specieNameLabel.textColor = .secondaryLabel
        capsuleIconView?.isHidden = true

        dateLabel?.text = nil
    }

    override var isSelected: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.applySelectionAppearance()
            }
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            })
        }
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySelectionAppearance()
    }

}
