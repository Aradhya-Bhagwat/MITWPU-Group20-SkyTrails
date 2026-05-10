
import UIKit

class UpcomingBirdsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardContainerView: UIView!
    @IBOutlet var birdImageView: UIImageView!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    private var currentImageTask: Task<Void, Never>?

    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
        setupUI()
        applySemanticAppearance()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }
    
    private func setupUI() {
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        cardContainerView.backgroundColor = .systemBackground
        cardContainerView.layer.cornerRadius = 16
        cardContainerView.layer.masksToBounds = true

        birdImageView.contentMode = .scaleAspectFill
        birdImageView.clipsToBounds = true
        birdImageView.layer.cornerRadius = 12
           
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
           
        dateLabel.textColor = .secondaryLabel
        
        }

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        cardContainerView.backgroundColor = cardColor

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
        guard cardContainerView != nil, dateLabel != nil, titleLabel != nil else { return }
        if traitCollection.userInterfaceStyle != .dark {
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    
        let currentWidth = self.bounds.width
        let titleRatio: CGFloat = 17.0 / 200.0
        let dateRatio: CGFloat = 12.0 / 200.0
        
        titleLabel.font = UIFont.systemFont(
            ofSize: currentWidth * titleRatio,
            weight: .semibold
        )
        
        let dynamicDateSize = currentWidth * dateRatio
            dateLabel.font = UIFont.systemFont(ofSize: dynamicDateSize, weight: .regular)
        
        if let text = dateLabel.text {
            dateLabel.attributedText = createIconString(
                text: text,
                iconName: "calendar",
                color: .secondaryLabel,
                fontSize: dynamicDateSize
            )
        }
    }
    
    override func prepareForReuse() {
           super.prepareForReuse()
           currentImageTask?.cancel()
           currentImageTask = nil
           birdImageView.image = UIImage(systemName: "bird.fill")
           titleLabel.text = nil
           dateLabel.text = nil
       }

    
    private func createIconString(text: String, iconName: String, color: UIColor, fontSize: CGFloat) -> NSAttributedString {
            let config = UIImage.SymbolConfiguration(pointSize: fontSize * 0.9, weight: .semibold)
            guard let icon = UIImage(systemName: iconName, withConfiguration: config)?
                .withTintColor(color, renderingMode: .alwaysOriginal) else { return NSAttributedString(string: text) }
            let attachment = NSTextAttachment(image: icon)
            let yOffset = (fontSize - icon.size.height) / 2.0 - 2
            attachment.bounds = CGRect(x: 0, y: yOffset, width: icon.size.width, height: icon.size.height)
            let completeString = NSMutableAttributedString(attachment: attachment)
            completeString.append(NSAttributedString(string: " " + text, attributes: [.foregroundColor: color]))
            
            return completeString
        }
       
       func configure(image: UIImage?, imageName: String? = nil, title: String, date: String) {
           currentImageTask?.cancel()
           birdImageView.image = image ?? UIImage(systemName: "bird.fill")
           
           if let imageName = imageName {
                print("[DEBUG] UpcomingBirdsCell - loading image for: \(imageName)")
                currentImageTask = Task { @MainActor in
                    if let fetched = await ImageService.shared.image(for: imageName) {
                        print("[DEBUG] UpcomingBirdsCell - SUCCESS loaded: \(imageName)")
                        if !Task.isCancelled {
                            self.birdImageView.image = fetched
                        }
                    } else {
                        print("[DEBUG] UpcomingBirdsCell - FAILED to load: \(imageName)")
                    }
                }
            }
           
           titleLabel.text = title
           
           let tagColor: UIColor
           switch date {
           case "Common Here": tagColor = .systemBlue
           case "Look Out For": tagColor = .systemOrange
           case "Rare Find": tagColor = .systemPink
           default: tagColor = .systemGray
           }
           dateLabel.textColor = tagColor
           dateLabel.attributedText = nil
           dateLabel.text = date
       }

    
}
