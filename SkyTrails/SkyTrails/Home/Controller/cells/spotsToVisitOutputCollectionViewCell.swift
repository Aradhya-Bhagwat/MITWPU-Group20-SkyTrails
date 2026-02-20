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

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
        updateCardVariant()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardVariant()
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
        compactBadgeTitleLabel.text = status.title
        compactBadgeSubtitleLabel.text = status.subtitle
        wideBadgeTitleLabel.text = status.title
        wideBadgeSubtitleLabel.text = status.subtitle

        let icon = UIImage(systemName: "binoculars.fill")
        compactBadgeIconImageView.image = icon
        wideBadgeIconImageView.image = icon
        compactBadgeIconImageView.tintColor = status.color
        wideBadgeIconImageView.tintColor = status.color

        compactSightabilityLabel.text = "Sightability - \(prediction.spottingProbability)%"
        wideSightabilityLabel.text = "Sightability - \(prediction.spottingProbability)%"

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
}
