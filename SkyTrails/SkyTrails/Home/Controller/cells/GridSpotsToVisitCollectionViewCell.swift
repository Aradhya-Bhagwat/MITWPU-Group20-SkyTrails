import UIKit
import MapKit

    class GridSpotsToVisitCollectionViewCell: UICollectionViewCell {

        static let identifier = "GridSpotsToVisitCollectionViewCell"

        @IBOutlet weak var locationImage: UIImageView!
        @IBOutlet weak var titleLabel: UILabel!
        @IBOutlet weak var locationLabel: UILabel!
        @IBOutlet weak var containerView: UIView!
        
        private var currentSpeciesCount: Int = 0
        private var currentSnapshotTask: Task<Void, Never>?
        private var representedSnapshotKey: String?
        private static let snapshotCache = NSCache<NSString, UIImage>()
        private var currentImageTask: Task<Void, Never>?

            override func awakeFromNib() {
                super.awakeFromNib()
                setupTraitChangeHandling()
                setupStyle()
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
                updateSpeciesLabel(count: currentSpeciesCount, fontSize: locationLabel.font.pointSize)
            }
            func configure(
                image: UIImage?,
                imageName: String? = nil,
                title: String,
                speciesCount: Int,
                latitude: Double? = nil,
                longitude: Double? = nil
            ) {
                currentImageTask?.cancel()
                currentSnapshotTask?.cancel()
                currentImageTask = nil
                currentSnapshotTask = nil
                
                self.titleLabel.text = title
                self.currentSpeciesCount = speciesCount
                
                // Reset image to placeholder
                locationImage.image = UIImage(systemName: "photo")
                
                currentImageTask = Task { @MainActor in
                    var finalImage = image
                    
                    if let imageName = imageName {
                        if let fetched = await ImageService.shared.image(for: imageName) {
                            finalImage = fetched
                        }
                    }
                    
                    if Task.isCancelled { return }
                    
                    let hasValidBirdImage = finalImage != nil && finalImage != UIImage(named: "placeholder_image")
                    
                    if !hasValidBirdImage, let latitude, let longitude {
                        let key = Self.snapshotKey(lat: latitude, lon: longitude)
                        representedSnapshotKey = key
                        if let cached = Self.snapshotCache.object(forKey: key as NSString) {
                            locationImage.image = cached
                        } else {
                            locationImage.image = finalImage ?? UIImage(systemName: "photo")
                            currentSnapshotTask = Task { [weak self] in
                                guard let self else { return }
                                let size = self.locationImage.bounds.size
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
                                    self.locationImage.image = rendered
                                }
                            }
                        }
                    } else {
                        locationImage.image = finalImage ?? UIImage(systemName: "photo")
                        representedSnapshotKey = nil
                    }
                }

                
                updateSpeciesLabel(count: speciesCount, fontSize: locationLabel.font.pointSize)
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

            private func updateSpeciesLabel(count: Int, fontSize: CGFloat) {
                let text = "\(count) Species all time"
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
                let yOffset = (fontSize - icon.size.height) / 2.0 - 1
                attachment.bounds = CGRect(x: 0, y: yOffset, width: icon.size.width, height: icon.size.height)
                
                let completeString = NSMutableAttributedString(attachment: attachment)
                completeString.append(NSAttributedString(string: " " + text, attributes: [.foregroundColor: color]))
                
                return completeString
            }
            
            override func prepareForReuse() {
                super.prepareForReuse()
                currentImageTask?.cancel()
                currentSnapshotTask?.cancel()
                currentImageTask = nil
                currentSnapshotTask = nil
                representedSnapshotKey = nil
                locationImage.image = nil
                titleLabel.text = nil
                locationLabel.attributedText = nil
                currentSpeciesCount = 0
            }

        }
