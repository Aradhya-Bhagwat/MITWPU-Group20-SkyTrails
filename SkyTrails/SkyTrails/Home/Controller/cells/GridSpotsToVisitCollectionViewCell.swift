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
            }

            private func setupStyle() {
                self.backgroundColor = .clear
                
                contentView.backgroundColor = .clear
                contentView.layer.cornerRadius = 16
                contentView.layer.masksToBounds = false
                contentView.layer.shadowColor = UIColor.black.cgColor
                contentView.layer.shadowOpacity = 0.15
                contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
                contentView.layer.shadowRadius = 8
                
                locationImage.contentMode = .scaleAspectFill
                locationImage.clipsToBounds = true
                locationImage.layer.cornerRadius = 12
                
                containerView.backgroundColor = .systemBackground
                containerView.layer.cornerRadius = 12
                
                titleLabel.numberOfLines = 1
                titleLabel.textColor = .label
                
                locationLabel.textColor = .secondaryLabel
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                
                contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath

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
