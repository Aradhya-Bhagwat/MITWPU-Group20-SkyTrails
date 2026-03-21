
import UIKit
import MapKit

class SpotsToVisitCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardContainerView2: UIView!
    @IBOutlet weak var birdImageView2: UIImageView!
    @IBOutlet weak var titleLabel2: UILabel!
    @IBOutlet weak var dateLabel2: UILabel!
    
    private var currentSpeciesCount: Int = 0
    private var currentSnapshotTask: Task<Void, Never>?
    private var representedSnapshotKey: String?
    private static let snapshotCache = NSCache<NSString, UIImage>()

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
        
        cardContainerView2.backgroundColor = .systemBackground
        cardContainerView2.layer.cornerRadius = 16
        cardContainerView2.layer.masksToBounds = true
        
        birdImageView2.contentMode = .scaleAspectFill
        birdImageView2.clipsToBounds = true
        birdImageView2.layer.cornerRadius = 12
        
        titleLabel2.numberOfLines = 1
        titleLabel2.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel2.textColor = .label
        
        dateLabel2.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        dateLabel2.textColor = .secondaryLabel
        
    }

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        cardContainerView2.backgroundColor = cardColor

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
        
        guard titleLabel2 != nil, dateLabel2 != nil else { return }
        
        if traitCollection.userInterfaceStyle != .dark {
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
        
        let currentWidth = self.bounds.width
        let titleRatio: CGFloat = 17.0 / 200.0
        let dateRatio: CGFloat = 12.0 / 200.0
        
        titleLabel2.font = UIFont.systemFont(
            ofSize: currentWidth * titleRatio,
            weight: .semibold
        )
        
        let dynamicDateSize = currentWidth * dateRatio
        dateLabel2.font = UIFont.systemFont(ofSize: dynamicDateSize, weight: .regular)
        updateSpeciesLabel(count: currentSpeciesCount, fontSize: dynamicDateSize)
        
    }
    private func updateSpeciesLabel(count: Int, fontSize: CGFloat) {
            let text = "\(count) Species active now"
            dateLabel2.attributedText = createIconString(
                text: text,
                iconName: "bird.fill",
                color: .systemGreen,
                fontSize: fontSize
            )
        }
    
    override func prepareForReuse() {
           super.prepareForReuse()
           currentSnapshotTask?.cancel()
           currentSnapshotTask = nil
           representedSnapshotKey = nil
           birdImageView2.image = nil
           titleLabel2.text = nil
           dateLabel2.text = nil
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
    
    func configure(
        image: UIImage?,
        title: String,
        speciesCount: Int,
        latitude: Double?,
        longitude: Double?
    ) {
            currentSnapshotTask?.cancel()
            currentSnapshotTask = nil
            self.titleLabel2.text = title
            self.currentSpeciesCount = speciesCount

            if let latitude, let longitude {
                let key = Self.snapshotKey(lat: latitude, lon: longitude)
                representedSnapshotKey = key
                if let cached = Self.snapshotCache.object(forKey: key as NSString) {
                    birdImageView2.image = cached
                } else {
                    birdImageView2.image = image
                    currentSnapshotTask = Task { [weak self] in
                        guard let self else { return }
                        let size = self.birdImageView2.bounds.size
                        let targetSize = size.width > 0 ? size : CGSize(width: 200, height: 120)
                        let rendered = await Self.snapshotImage(
                            latitude: latitude,
                            longitude: longitude,
                            targetSize: targetSize
                        )
                        guard !Task.isCancelled, let rendered else { return }
                        await MainActor.run {
                            guard self.representedSnapshotKey == key else { return }
                            Self.snapshotCache.setObject(rendered, forKey: key as NSString)
                            self.birdImageView2.image = rendered
                        }
                    }
                }
            } else {
                birdImageView2.image = image
                representedSnapshotKey = nil
            }

            updateSpeciesLabel(count: speciesCount, fontSize: dateLabel2.font.pointSize)
        }

    private static func snapshotKey(lat: Double, lon: Double) -> String {
        String(format: "%.4f,%.4f", lat, lon)
    }

    private static func snapshotImage(
        latitude: Double,
        longitude: Double,
        targetSize: CGSize
    ) async -> UIImage? {
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else {
            return nil
        }

        let snapshotWidth = max(80, targetSize.width)
        let snapshotHeight = max(80, targetSize.height)
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        let options = MKMapSnapshotter.Options()
        options.size = CGSize(width: snapshotWidth, height: snapshotHeight)
        options.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        options.mapType = .hybrid

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            return snapshot.image
        } catch {
            return nil
        }
    }
}
