//
//  spotsToVisitOutputCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 20/02/26.
//

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
    @IBOutlet weak var graphView: SightabilityGraphView!

    private var showsWideCard: Bool?
    private var isCardSelected = false
    private let baseCardHeight: CGFloat = 126.0
    private var currentStatusColor: UIColor = .systemBlue
    private var currentStatusTitle: String = ""
    private var currentStatusSubtitle: String = ""
    private var currentSightabilityText: String = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
        updateCardVariant()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateScaledLayout()
        updateCardVariant()
        applyBadgeIconStyle()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath
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
        let image = UIImage(named: prediction.imageName) ?? UIImage(systemName: "bird.fill")
        compactBirdImageView.image = image
        wideBirdImageView.image = image

        compactBirdNameLabel.text = prediction.birdName
        wideBirdNameLabel.text = prediction.birdName

        let status = statusText(for: prediction.spottingProbability)
        currentStatusTitle = status.title
        currentStatusSubtitle = status.subtitle
        currentStatusColor = status.color
        currentSightabilityText = "Sightability - \(prediction.spottingProbability)%"
        applyScaledTexts()
        applyBadgeIconStyle()

        graphView.setProbabilities(yearlyProbabilities)
        applySelectionStyle()
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
        let heightRatio = max(0.7, bounds.height / baseCardHeight)
        let titleSize = max(17, 17 * heightRatio)
        let bodySize = max(12, 12 * heightRatio)

        compactBirdNameLabel.font = .systemFont(ofSize: titleSize, weight: .regular)
        wideBirdNameLabel.font = .systemFont(ofSize: titleSize, weight: .regular)

        compactBadgeTitleLabel.font = .systemFont(ofSize: bodySize)
        compactBadgeSubtitleLabel.font = .systemFont(ofSize: bodySize)
        wideBadgeTitleLabel.font = .systemFont(ofSize: bodySize)
        wideBadgeSubtitleLabel.font = .systemFont(ofSize: bodySize)
        compactSightabilityLabel.font = .systemFont(ofSize: bodySize)
        wideSightabilityLabel.font = .systemFont(ofSize: bodySize)

        applyScaledTexts()
    }

    private func applyScaledTexts() {
        compactBadgeTitleLabel.text = currentStatusTitle
        compactBadgeSubtitleLabel.text = currentStatusSubtitle
        wideBadgeTitleLabel.text = currentStatusTitle
        wideBadgeSubtitleLabel.text = currentStatusSubtitle
        compactSightabilityLabel.text = currentSightabilityText
        wideSightabilityLabel.text = currentSightabilityText
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
