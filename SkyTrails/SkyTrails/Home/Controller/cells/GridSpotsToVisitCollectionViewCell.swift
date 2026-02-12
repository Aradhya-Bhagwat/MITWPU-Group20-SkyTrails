//
//  SpotsToVisitCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//
    import UIKit

    class GridSpotsToVisitCollectionViewCell: UICollectionViewCell {

        static let identifier = "GridSpotsToVisitCollectionViewCell"

        @IBOutlet weak var locationImage: UIImageView!
        @IBOutlet weak var titleLabel: UILabel!
        @IBOutlet weak var locationLabel: UILabel!
        @IBOutlet weak var containerView: UIView!
        
        private var currentSpeciesCount: Int = 0

            override func awakeFromNib() {
                super.awakeFromNib()
                setupStyle()
                applySemanticAppearance()
            }

            override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
                super.traitCollectionDidChange(previousTraitCollection)
                guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
                applySemanticAppearance()
            }

            private func setupStyle() {
                self.backgroundColor = .clear
                
                contentView.backgroundColor = .clear
                contentView.layer.cornerRadius = 16
                contentView.layer.masksToBounds = false
                
                locationImage.contentMode = .scaleAspectFill
                locationImage.clipsToBounds = true
                locationImage.layer.cornerRadius = 12
                
                containerView.backgroundColor = .systemBackground
                containerView.layer.cornerRadius = 12
                containerView.layer.masksToBounds = true
                
                titleLabel.numberOfLines = 1
                titleLabel.textColor = .label
                
                locationLabel.textColor = .secondaryLabel
            }

            private func applySemanticAppearance() {
                let isDarkMode = traitCollection.userInterfaceStyle == .dark
                let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

                backgroundColor = .clear
                contentView.backgroundColor = .clear
                containerView.backgroundColor = cardColor

                if isDarkMode {
                    contentView.layer.shadowOpacity = 0
                    contentView.layer.shadowRadius = 0
                    contentView.layer.shadowOffset = .zero
                    contentView.layer.shadowPath = nil
                } else {
                    contentView.layer.shadowColor = UIColor.black.cgColor
                    contentView.layer.shadowOpacity = 0.08
                    contentView.layer.shadowOffset = CGSize(width: 0, height: 3)
                    contentView.layer.shadowRadius = 6
                    contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
                }
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                if traitCollection.userInterfaceStyle != .dark {
                    contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
                }

                let currentWidth = self.bounds.width
                let titleRatio: CGFloat = 17.0 / 200.0
                let locationRatio: CGFloat = 12.0 / 200.0
                
                let calculatedTitleSize = min(currentWidth * titleRatio, 30.0)
                let calculatedLocSize = min(currentWidth * locationRatio, 18.0)

                titleLabel.font = UIFont.systemFont(ofSize: calculatedTitleSize, weight: .semibold)
                locationLabel.font = UIFont.systemFont(ofSize: calculatedLocSize, weight: .regular)
                
                // 💡 Update the attributed text during the layout pass to ensure icon scales with font
                updateSpeciesLabel(count: currentSpeciesCount, fontSize: locationLabel.font.pointSize)
            }
         
            // 💡 New configuration method to match your live-data logic
            func configure(image: UIImage?, title: String, speciesCount: Int) {
                locationImage.image = image
                titleLabel.text = title
                self.currentSpeciesCount = speciesCount
                
                updateSpeciesLabel(count: speciesCount, fontSize: locationLabel.font.pointSize)
            }
            
            private func updateSpeciesLabel(count: Int, fontSize: CGFloat) {
                let text = "\(count) Species active now"
                locationLabel.attributedText = createIconString(
                    text: text,
                    iconName: "bird.fill",
                    color: .systemGreen,
                    fontSize: fontSize
                )
            }

            private func createIconString(text: String, iconName: String, color: UIColor, fontSize: CGFloat) -> NSAttributedString {
                let config = UIImage.SymbolConfiguration(pointSize: fontSize * 0.9, weight: .semibold)
                guard let icon = UIImage(systemName: iconName, withConfiguration: config)?
                    .withTintColor(color, renderingMode: .alwaysOriginal) else {
                        return NSAttributedString(string: text)
                }
                
                let attachment = NSTextAttachment(image: icon)
                // Vertically center the icon relative to the text line
                let yOffset = (fontSize - icon.size.height) / 2.0 - 1
                attachment.bounds = CGRect(x: 0, y: yOffset, width: icon.size.width, height: icon.size.height)
                
                let completeString = NSMutableAttributedString(attachment: attachment)
                completeString.append(NSAttributedString(string: " " + text, attributes: [.foregroundColor: color]))
                
                return completeString
            }
            
            override func prepareForReuse() {
                super.prepareForReuse()
                locationImage.image = nil
                titleLabel.text = nil
                locationLabel.attributedText = nil
                currentSpeciesCount = 0
            }
        }
