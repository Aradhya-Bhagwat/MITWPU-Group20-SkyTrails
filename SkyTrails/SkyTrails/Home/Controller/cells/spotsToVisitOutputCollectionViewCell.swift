
import UIKit

final class spotsToVisitOutputCollectionViewCell: UICollectionViewCell {
    static let identifier = "spotsToVisitOutputCollectionViewCell"

    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var compactCardView: UIView!
    @IBOutlet weak var wideCardView: UIView!

    @IBOutlet weak var compactBirdImageView: UIImageView!
    @IBOutlet weak var compactBirdNameLabel: UILabel!
    @IBOutlet weak var compactBadgeIconImageView: UIImageView!
    @IBOutlet weak var compactBadgeTitleLabel: UILabel!
    @IBOutlet weak var compactBadgeSubtitleLabel: UILabel!
    @IBOutlet weak var compactSightabilityLabel: UILabel!

    @IBOutlet weak var wideBirdImageView: UIImageView!
    @IBOutlet weak var wideBirdNameLabel: UILabel!
    @IBOutlet weak var wideBadgeIconImageView: UIImageView!
    @IBOutlet weak var wideBadgeTitleLabel: UILabel!
    @IBOutlet weak var wideBadgeSubtitleLabel: UILabel!
    @IBOutlet weak var wideSightabilityLabel: UILabel!

    private var showsWideCard: Bool?
    private var isCardSelected = false
    private var currentStatusColor: UIColor = .systemBlue
    private var currentStatusTitle: String = ""
    private var currentStatusSubtitle: String = ""
    private var currentProbability: Int = 0

    private var actionButtonsContainer: UIStackView?
    private var currentPrediction: FinalPredictionResult?
    private var hasConfiguredLayoutBehavior = false
    private var hasInstalledCompactTopRowFix = false
    private var compactBadgeContainerWidthConstraint: NSLayoutConstraint?
    private var compactBadgeContainerHeightConstraint: NSLayoutConstraint?
    private var wideBadgeContainerWidthConstraint: NSLayoutConstraint?
    private var wideBadgeContainerHeightConstraint: NSLayoutConstraint?
    
    private let graphView: SightabilityGraphView = {
        let v = SightabilityGraphView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()
    
    var onTapBirdPath: ((FinalPredictionResult) -> Void)?
    var onTapWatchlist: ((FinalPredictionResult) -> Void)?
    
    private var currentImageTask: Task<Void, Never>?


    override func awakeFromNib() {
        setupLayoutBehavior()
        setupGraphView()
        updateCardVariant()
        setupActionButtons()
    }

    private func setupGraphView() {
        wideCardView.addSubview(graphView)
        NSLayoutConstraint.activate([
            graphView.trailingAnchor.constraint(equalTo: wideCardView.trailingAnchor, constant: -16),
            graphView.bottomAnchor.constraint(equalTo: wideCardView.bottomAnchor, constant: -12),
            graphView.widthAnchor.constraint(equalTo: wideCardView.widthAnchor, multiplier: 0.35),
            graphView.heightAnchor.constraint(equalToConstant: 130)
        ])
        
        wideSightabilityLabel.translatesAutoresizingMaskIntoConstraints = false
        if let superview = wideSightabilityLabel.superview {
            let constraints = superview.constraints.filter { 
                $0.firstItem === wideSightabilityLabel || $0.secondItem === wideSightabilityLabel 
            }
            NSLayoutConstraint.deactivate(constraints)
            
            NSLayoutConstraint.activate([
                wideSightabilityLabel.topAnchor.constraint(equalTo: wideBadgeSubtitleLabel.bottomAnchor, constant: 8),
                wideSightabilityLabel.leadingAnchor.constraint(equalTo: wideBadgeSubtitleLabel.leadingAnchor),
                wideSightabilityLabel.trailingAnchor.constraint(lessThanOrEqualTo: graphView.leadingAnchor, constant: -12)
            ])
            wideSightabilityLabel.textAlignment = .left
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentImageTask?.cancel()
        currentImageTask = nil
        compactBirdImageView.image = UIImage(systemName: "bird.fill")
        wideBirdImageView.image = UIImage(systemName: "bird.fill")
    }


    override func layoutSubviews() {
        super.layoutSubviews()
        installCompactTopRowFixIfNeeded()
        updateScaledLayout()
        updateCardVariant()
        applyBadgeIconStyle()
        let cardView = (bounds.width >= 450) ? wideCardView : compactCardView
        if let card = cardView {
            let cardFrame = card.convert(card.bounds, to: self)
            layer.shadowPath = UIBezierPath(roundedRect: cardFrame, cornerRadius: 12).cgPath
        } else {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath
        }
    }

    private func setupAppearance() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true

        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 7

        compactCardView.layer.cornerRadius = 12
        wideCardView.layer.cornerRadius = 12
        compactCardView.layer.masksToBounds = true
        wideCardView.layer.masksToBounds = true
        compactCardView.backgroundColor = .systemBackground
        wideCardView.backgroundColor = .systemBackground

        compactBirdImageView.layer.cornerRadius = 8
        wideBirdImageView.layer.cornerRadius = 8
        compactBirdImageView.clipsToBounds = true
        wideBirdImageView.clipsToBounds = true

        compactBirdNameLabel.textColor = .label
        wideBirdNameLabel.textColor = .label
        compactBadgeTitleLabel.textColor = .label
        wideBadgeTitleLabel.textColor = .label
        compactBadgeSubtitleLabel.textColor = .secondaryLabel
        wideBadgeSubtitleLabel.textColor = .secondaryLabel
        compactSightabilityLabel.textColor = .secondaryLabel
        wideSightabilityLabel.textColor = .secondaryLabel
    }

    private func setupActionButtons() {
        guard actionButtonsContainer == nil else { return }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true

        let watchlistBtn = createActionButton(title: "Add to Watchlist")
        watchlistBtn.addTarget(self, action: #selector(didTapWatchlist), for: .touchUpInside)
        let pathBtn = createActionButton(title: "Predict Species")
        pathBtn.addTarget(self, action: #selector(didTapPath), for: .touchUpInside)

        stack.addArrangedSubview(watchlistBtn)
        stack.addArrangedSubview(pathBtn)

        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)
        wrapper.isHidden = true
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: 0),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])

        mainStackView.addArrangedSubview(wrapper)
        mainStackView.axis = .vertical
        mainStackView.sendSubviewToBack(wrapper)
        
        self.actionButtonsContainer = stack
    }

    private func createActionButton(title: String, systemName: String? = nil, imageName: String? = nil) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        if let systemName = systemName {
            button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        } else if let imageName = imageName {
            button.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }

        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.semanticContentAttribute = .forceLeftToRight
        button.contentHorizontalAlignment = .center
   
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 44),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        button.layer.cornerRadius = 22
        
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.masksToBounds = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        return button
    }

    private func setupLayoutBehavior() {
        guard !hasConfiguredLayoutBehavior else { return }
        hasConfiguredLayoutBehavior = true

        compactBirdNameLabel.numberOfLines = 1
        compactBirdNameLabel.lineBreakMode = .byTruncatingTail
        compactBirdNameLabel.adjustsFontSizeToFitWidth = true
        compactBirdNameLabel.minimumScaleFactor = 0.85
        compactBirdNameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        compactBirdNameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        compactBirdNameLabel.textAlignment = .left

        wideBirdNameLabel.numberOfLines = 1
        wideBirdNameLabel.lineBreakMode = .byTruncatingTail
        wideBirdNameLabel.adjustsFontSizeToFitWidth = true
        wideBirdNameLabel.minimumScaleFactor = 0.9
        wideBirdNameLabel.textAlignment = .left

        [compactSightabilityLabel, wideSightabilityLabel].forEach { label in
            label?.numberOfLines = 1
            label?.lineBreakMode = .byTruncatingTail
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.72
            label?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label?.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        compactSightabilityLabel.textAlignment = .left
        wideSightabilityLabel.textAlignment = .right

        [compactBadgeTitleLabel, compactBadgeSubtitleLabel, wideBadgeTitleLabel, wideBadgeSubtitleLabel].forEach { label in
            label?.numberOfLines = 1
            label?.lineBreakMode = .byTruncatingTail
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.82
        }

        compactBadgeTitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        compactBadgeSubtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        wideBadgeTitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        wideBadgeSubtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        if let compactBadgeContainer = compactBadgeIconImageView.superview {
            compactBadgeContainer.translatesAutoresizingMaskIntoConstraints = false
            let width = compactBadgeContainer.widthAnchor.constraint(equalToConstant: 42)
            let height = compactBadgeContainer.heightAnchor.constraint(equalToConstant: 42)
            width.priority = .required
            height.priority = .required
            NSLayoutConstraint.activate([width, height])
            compactBadgeContainerWidthConstraint = width
            compactBadgeContainerHeightConstraint = height
        }

        if let wideBadgeContainer = wideBadgeIconImageView.superview {
            wideBadgeContainer.translatesAutoresizingMaskIntoConstraints = false
            let width = wideBadgeContainer.widthAnchor.constraint(equalToConstant: 28)
            let height = wideBadgeContainer.heightAnchor.constraint(equalToConstant: 28)
            width.priority = .required
            height.priority = .required
            NSLayoutConstraint.activate([width, height])
            wideBadgeContainerWidthConstraint = width
            wideBadgeContainerHeightConstraint = height
        }
    }

    private func installCompactTopRowFixIfNeeded() {
        guard !hasInstalledCompactTopRowFix else { return }
        guard compactBirdNameLabel.superview === compactCardView,
              compactSightabilityLabel.superview === compactCardView,
              let compactStatusContainer = compactBadgeIconImageView.superview?.superview else { return }

        hasInstalledCompactTopRowFix = true

        for constraint in compactCardView.constraints {
            let first = constraint.firstItem as AnyObject?
            let second = constraint.secondItem as AnyObject?
            let touchesCompactSightability = first === compactSightabilityLabel || second === compactSightabilityLabel
            let touchesCompactImage = first === compactBirdImageView || second === compactBirdImageView
            let touchesCompactBirdName = first === compactBirdNameLabel || second === compactBirdNameLabel
            let touchesCompactStatusContainer = first === compactStatusContainer || second === compactStatusContainer

            if touchesCompactSightability && touchesCompactImage && constraint.firstAttribute == .leading {
                constraint.isActive = false
            }

            if touchesCompactSightability && constraint.firstAttribute == .top {
                constraint.isActive = false
            }

            if touchesCompactSightability && touchesCompactBirdName && constraint.firstAttribute == .trailing {
                constraint.isActive = false
            }

            if touchesCompactStatusContainer && constraint.firstAttribute == .centerY {
                constraint.isActive = false
            }
        }

        NSLayoutConstraint.activate([
            compactSightabilityLabel.topAnchor.constraint(equalTo: compactBirdNameLabel.bottomAnchor, constant: 10),
            compactSightabilityLabel.leadingAnchor.constraint(equalTo: compactBirdNameLabel.leadingAnchor),
            compactSightabilityLabel.trailingAnchor.constraint(lessThanOrEqualTo: compactCardView.trailingAnchor, constant: -12),
            compactStatusContainer.topAnchor.constraint(equalTo: compactSightabilityLabel.bottomAnchor, constant: 14)
        ])
    }

    private func updateCardVariant() {
        let shouldShowWide = bounds.width >= 450
        if let current = showsWideCard, current == shouldShowWide {
            return
        }

        showsWideCard = shouldShowWide
        compactCardView.isHidden = shouldShowWide
        wideCardView.isHidden = !shouldShowWide
        mainStackView.layoutIfNeeded()
    }

    func configure(prediction: FinalPredictionResult, yearlyProbabilities: [Int]) {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        graphView.currentWeek = currentWeek
        if yearlyProbabilities.isEmpty {
            graphView.isLoading = true
            graphView.scores = []
        } else {
            graphView.isLoading = false
            graphView.scores = yearlyProbabilities
        }
        self.currentPrediction = prediction
        
        currentImageTask?.cancel()
        compactBirdImageView.image = UIImage(systemName: "bird.fill")
        wideBirdImageView.image = UIImage(systemName: "bird.fill")

        currentImageTask = Task { @MainActor in
            let image = await ImageService.shared.image(for: prediction.imageName)
            if !Task.isCancelled {
                let finalImage = image ?? UIImage(systemName: "bird.fill")
                self.compactBirdImageView.image = finalImage
                self.wideBirdImageView.image = finalImage
            }
        }


        compactBirdNameLabel.text = prediction.birdName
        wideBirdNameLabel.text = prediction.birdName

        currentStatusTitle = prediction.weekNumber ?? "N/A"
        currentStatusSubtitle = prediction.residencyStatus ?? "N/A"
        currentStatusColor = statusText(for: prediction.spottingProbability).color
        currentProbability = prediction.spottingProbability
        applyScaledTexts()
        applyBadgeIconStyle()

        applySelectionStyle()
    }

    @objc private func didTapPath() {
        guard let prediction = currentPrediction else { return }
        onTapBirdPath?(prediction)
    }

    @objc private func didTapWatchlist() {
        guard let prediction = currentPrediction else { return }
        onTapWatchlist?(prediction)
    }

    func setCardSelected(_ selected: Bool) {
        isCardSelected = selected
        applySelectionStyle()
    }

    private func statusText(for probability: Int) -> (title: String, subtitle: String, color: UIColor) {
        switch probability {
        case 80...100:
            return ("High", "Likely Today", .systemGreen)
        case 50...79:
            return ("Moderate", "Watch Nearby", .systemBlue)
        default:
            return ("Low", "Rare Chance", .systemOrange)
        }
    }

    private func applySelectionStyle() {
        let borderColor = isCardSelected ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        let borderWidth: CGFloat = isCardSelected ? 2 : 0
        compactCardView.layer.borderColor = borderColor
        compactCardView.layer.borderWidth = borderWidth
        wideCardView.layer.borderColor = borderColor
        wideCardView.layer.borderWidth = borderWidth
        
        guard let container = actionButtonsContainer?.superview else { return }
        
        if isCardSelected {
            container.isHidden = false
            actionButtonsContainer?.isHidden = false
            container.alpha = 0
            container.transform = CGAffineTransform(translationX: 0, y: -40)
            
            UIView.animate(withDuration: 0.35, delay: 0.05, options: [.curveEaseOut, .allowUserInteraction]) {
                container.alpha = 1
                container.transform = .identity
            }
        } else {
            container.alpha = 0
            container.isHidden = true
            actionButtonsContainer?.isHidden = true
            container.transform = .identity
        }
    }

    private func styleBadgeIconContainer(_ imageView: UIImageView, color: UIColor) {
        guard let container = imageView.superview else { return }
        container.layoutIfNeeded()
        container.backgroundColor = color.withAlphaComponent(0.2)
        let side = min(container.bounds.width, container.bounds.height)
        if side > 0 {
            container.layer.cornerRadius = side / 2
            container.clipsToBounds = true
        }
    }

    private func updateScaledLayout() {
        let isWide = bounds.width >= 450
        let cardView = isWide ? wideCardView : compactCardView
        let currentWidth = max(1, cardView?.bounds.width ?? bounds.width)
        let titleScaleWidth = currentWidth * (18.0 / 200.0)
        let bodyScaleWidth = currentWidth * (12.0 / 200.0)
        let sightabilityScaleWidth = currentWidth * (13.5 / 200.0)
        let titleSize = isWide
            ? min(max(titleScaleWidth, 17), 24)
            : min(max(titleScaleWidth, 17), 20)
        let bodySize = isWide
            ? min(max(bodyScaleWidth, 17), 20)
            : min(max(bodyScaleWidth, 11), 13.5)
        let sightabilitySize = isWide
            ? min(max(sightabilityScaleWidth, 13), 16)
            : min(max(sightabilityScaleWidth, 12.5), 15.5)

        compactBirdNameLabel.font = .systemFont(ofSize: titleSize, weight: .semibold)
        wideBirdNameLabel.font = .systemFont(ofSize: titleSize, weight: .semibold)

        compactBadgeTitleLabel.font = .systemFont(ofSize: bodySize, weight: .semibold)
        compactBadgeSubtitleLabel.font = .systemFont(ofSize: bodySize, weight: .regular)
        wideBadgeTitleLabel.font = .systemFont(ofSize: bodySize, weight: .semibold)
        wideBadgeSubtitleLabel.font = .systemFont(ofSize: max(bodySize - 1, 16), weight: .regular)
        compactSightabilityLabel.font = .systemFont(ofSize: sightabilitySize, weight: .medium)
        wideSightabilityLabel.font = .systemFont(ofSize: sightabilitySize, weight: .medium)

        compactBadgeContainerWidthConstraint?.constant = min(max(bodySize * 2.9, 36), 44)
        compactBadgeContainerHeightConstraint?.constant = compactBadgeContainerWidthConstraint?.constant ?? 42
        wideBadgeContainerWidthConstraint?.constant = min(max(bodySize * 2.2, 38), 46)
        wideBadgeContainerHeightConstraint?.constant = wideBadgeContainerWidthConstraint?.constant ?? 28

        applyScaledTexts()
    }

    private func applyScaledTexts() {
        compactBadgeTitleLabel.text = currentStatusTitle
        compactBadgeSubtitleLabel.text = currentStatusSubtitle
        wideBadgeTitleLabel.text = currentStatusTitle
        wideBadgeSubtitleLabel.text = currentStatusSubtitle
        
        let sightabilityAttr = attributedSightabilityText(
            probability: currentProbability,
            font: compactSightabilityLabel.font
        )
        compactSightabilityLabel.attributedText = sightabilityAttr
        wideSightabilityLabel.attributedText = sightabilityAttr
    }

    private func colorForSightability(_ probability: Int) -> UIColor {
        switch probability {
        case 0..<25:
            return UIColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0)
        case 25..<50:
            return UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1.0)
        case 50..<75:
            return UIColor(red: 0.65, green: 0.8, blue: 0.0, alpha: 1.0)
        default:
            return UIColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0)
        }
    }

    private func attributedSightabilityText(probability: Int, font: UIFont) -> NSAttributedString {
        let color = colorForSightability(probability)
        let fontSize = font.pointSize
        let config = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .bold)
        let boldFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        
        let attributedString = NSMutableAttributedString()
        if let icon = UIImage(systemName: "binoculars.fill", withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal) {
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - icon.size.height) / 2, width: icon.size.width, height: icon.size.height)
            attributedString.append(NSAttributedString(attachment: attachment))
        }
        attributedString.append(NSAttributedString(string: " Sightability - ", attributes: [.font: font, .foregroundColor: UIColor.label]))
        attributedString.append(NSAttributedString(string: "\(probability)%", attributes: [.font: boldFont, .foregroundColor: color]))
        
        return attributedString
    }

    private func applyBadgeIconStyle() {
        styleBadgeIconContainer(compactBadgeIconImageView, color: currentStatusColor)
        styleBadgeIconContainer(wideBadgeIconImageView, color: currentStatusColor)

        updateBadgeIcon(compactBadgeIconImageView, color: currentStatusColor)
        updateBadgeIcon(wideBadgeIconImageView, color: currentStatusColor)
    }

    private func updateBadgeIcon(_ imageView: UIImageView, color: UIColor) {
        let baseSize = max(12, min(imageView.bounds.width, imageView.bounds.height) * 0.9)
        let symbolPointSize = max(baseSize, compactBadgeTitleLabel.font.pointSize)
        let iconConfig = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        imageView.image = UIImage(systemName: "bird.circle.fill", withConfiguration: iconConfig)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        imageView.tintColor = color
    }
}
