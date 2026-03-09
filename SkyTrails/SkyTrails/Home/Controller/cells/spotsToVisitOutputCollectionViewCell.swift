
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
    @IBOutlet weak var compactLikelySpotLabel: UILabel!
    @IBOutlet weak var compactSightabilityLabel: UILabel!

    @IBOutlet weak var wideBirdImageView: UIImageView!
    @IBOutlet weak var wideBirdNameLabel: UILabel!
    @IBOutlet weak var wideBadgeIconImageView: UIImageView!
    @IBOutlet weak var wideBadgeTitleLabel: UILabel!
    @IBOutlet weak var wideBadgeSubtitleLabel: UILabel!
    @IBOutlet weak var wideLikelySpotLabel: UILabel!
    @IBOutlet weak var wideSightabilityLabel: UILabel!
    @IBOutlet weak var graphView: SightabilityGraphView!

    private var showsWideCard: Bool?
    private var isCardSelected = false
    private let baseCardHeight: CGFloat = 126.0
    private var currentStatusColor: UIColor = .systemBlue
    private var currentStatusTitle: String = ""
    private var currentStatusSubtitle: String = ""
    private var currentLikelySpotText: String = ""
    private var currentProbability: Int = 0

    private var actionButtonsContainer: UIStackView?
    private var currentPrediction: FinalPredictionResult?
    
    var onTapBirdPath: ((FinalPredictionResult) -> Void)?
    var onTapWatchlist: ((FinalPredictionResult) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        mainStackView.distribution = .fill
        setupAppearance()
        updateCardVariant()
        setupActionButtons()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
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

        let watchlistBtn = createActionButton(imageName: "SF_addToWatchlist")
        watchlistBtn.addTarget(self, action: #selector(didTapWatchlist), for: .touchUpInside)
        let pathBtn = createActionButton(imageName: "SF_birdPath")
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

    private func createActionButton(systemName: String? = nil, imageName: String? = nil) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        if let systemName = systemName {
            button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        } else if let imageName = imageName {
            button.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }

        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        button.layer.cornerRadius = 22
        
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.masksToBounds = false

        return button
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
        self.currentPrediction = prediction
        let image = UIImage(named: prediction.imageName) ?? UIImage(systemName: "bird.fill")
        compactBirdImageView.image = image
        wideBirdImageView.image = image

        compactBirdNameLabel.text = prediction.birdName
        wideBirdNameLabel.text = prediction.birdName

        let status = statusText(for: prediction.spottingProbability)
        currentStatusTitle = prediction.weekNumber ?? "N/A"
        currentStatusSubtitle = prediction.residencyStatus ?? "N/A"
        currentLikelySpotText = "Likely Spot: \(prediction.likelySpot)"
        currentStatusColor = status.color
        currentProbability = prediction.spottingProbability
        applyScaledTexts()
        applyBadgeIconStyle()

        graphView.setProbabilities(yearlyProbabilities)
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
        let cardHeight = cardView?.bounds.height ?? bounds.height
        let maxRatio: CGFloat = isWide ? 1.12 : 1.0
        let heightRatio = min(maxRatio, max(0.85, cardHeight / baseCardHeight))
        let titleSize = max(17, 17 * heightRatio)
        let bodySize = max(12, 12 * heightRatio)

        compactBirdNameLabel.font = .systemFont(ofSize: titleSize, weight: .regular)
        wideBirdNameLabel.font = .systemFont(ofSize: titleSize, weight: .regular)

        compactBadgeTitleLabel.font = .systemFont(ofSize: bodySize)
        compactBadgeSubtitleLabel.font = .systemFont(ofSize: bodySize)
        wideBadgeTitleLabel.font = .systemFont(ofSize: bodySize)
        wideBadgeSubtitleLabel.font = .systemFont(ofSize: bodySize)
        compactLikelySpotLabel.font = .systemFont(ofSize: bodySize)
        wideLikelySpotLabel.font = .systemFont(ofSize: bodySize)
        compactSightabilityLabel.font = .systemFont(ofSize: bodySize)
        wideSightabilityLabel.font = .systemFont(ofSize: bodySize)

        applyScaledTexts()
    }

    private func applyScaledTexts() {
        compactBadgeTitleLabel.text = currentStatusTitle
        compactBadgeSubtitleLabel.text = currentStatusSubtitle
        wideBadgeTitleLabel.text = currentStatusTitle
        wideBadgeSubtitleLabel.text = currentStatusSubtitle
        compactLikelySpotLabel.text = currentLikelySpotText
        wideLikelySpotLabel.text = currentLikelySpotText
        
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
