//
//  NewMigrationCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 17/02/26.
//

import UIKit
import MapKit

class NewMigrationCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "NewMigrationCollectionViewCell"
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var weekLabel: UILabel!
    @IBOutlet weak var tagsStackView: UIStackView!
    @IBOutlet weak var tag1View: UIView!
    @IBOutlet weak var terrainTagImageView: UIImageView!
    @IBOutlet weak var terrainTagLabel: UILabel!
    @IBOutlet weak var tag2View: UIView!
    @IBOutlet weak var seasonTagImageView: UIImageView!
    @IBOutlet weak var seasonTagLabel: UILabel!
    @IBOutlet weak var birdListCollectionView: UICollectionView!
    
    private var birdSpecies: [BirdSpeciesDisplay] = []
    private var selectedBirdIndex: Int = 0
    private let expandedWidthRatio: CGFloat = 25.0 / 9.0
    private let compactWidthRatio: CGFloat = 5.0 / 6.0
    private let nestedItemHeightRatio: CGFloat = 90.0 / 440.0

    private final class BirdPinAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let birdImageName: String
        let birdIndex: Int
        let pinColor: UIColor

        init(coordinate: CLLocationCoordinate2D, birdImageName: String, birdIndex: Int, pinColor: UIColor) {
            self.coordinate = coordinate
            self.birdImageName = birdImageName
            self.birdIndex = birdIndex
            self.pinColor = pinColor
            super.init()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCollectionView()
        setupAppearance()
    }
    
    private func setupCollectionView() {
        birdListCollectionView.delegate = self
        birdListCollectionView.dataSource = self
        birdListCollectionView.register(UINib(nibName: subcardViewCell.identifier, bundle: Bundle(for: subcardViewCell.self)), forCellWithReuseIdentifier: subcardViewCell.identifier)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        birdListCollectionView.collectionViewLayout = layout
        birdListCollectionView.showsHorizontalScrollIndicator = false
        birdListCollectionView.backgroundColor = .clear
        birdListCollectionView.decelerationRate = .normal
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateNestedLayout()
        
        // Ensure capsule shape for tags
        tag1View.layer.cornerRadius = tag1View.bounds.height / 2
        tag2View.layer.cornerRadius = tag2View.bounds.height / 2
        seasonTagImageView.layer.cornerRadius = seasonTagImageView.bounds.height / 2
    }
    
    private func updateNestedLayout() {
        let cardHeight = self.bounds.height
        
        // 1. Scale Fonts
        let heightRatio = cardHeight / 440.0
        
        // Title: Min 17, max scales with height
        let titleSize = max(17, 17 * heightRatio)
        titleLabel.font = .systemFont(ofSize: titleSize, weight: .bold)
        
        // Others: Min 12, max scales with height
        let otherSize = max(12, 12 * heightRatio)
        subtitleLabel.font = .systemFont(ofSize: otherSize)
        weekLabel.font = .systemFont(ofSize: otherSize)
        terrainTagLabel.font = .systemFont(ofSize: otherSize, weight: .medium)
        seasonTagLabel.font = .systemFont(ofSize: otherSize, weight: .medium)
        
        // Distance label needs special handling for attributed string size
        updateDistanceLabelFont(size: otherSize)
        
        // 2. Scale Nested CollectionView Items
        if let layout = birdListCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let itemHeight = nestedItemHeight(cardHeight: cardHeight)
            let compactItemWidth = compactItemWidth(itemHeight: itemHeight)
            let newSize = CGSize(width: compactItemWidth, height: itemHeight)
            if layout.itemSize != newSize {
                layout.itemSize = newSize
                layout.invalidateLayout()
            }
        }
    }
    
    private func nestedItemHeight(cardHeight: CGFloat) -> CGFloat {
        return cardHeight * nestedItemHeightRatio
    }
    
    private func expandedItemWidth(itemHeight: CGFloat) -> CGFloat {
        var width = itemHeight * expandedWidthRatio
        if width > 400 {
            width = 400
        }
        return width
    }
    
    private func compactItemWidth(itemHeight: CGFloat) -> CGFloat {
        return itemHeight * compactWidthRatio
    }
    
    private func updateDistanceLabelFont(size: CGFloat) {
        guard let existingText = distanceLabel.attributedText?.string else { return }
        // The string starts with symbol attachment + " - " + distance
        // We need to re-create it to scale the symbol too
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        let symbolImage = UIImage(systemName: "mappin.and.ellipse", withConfiguration: symbolConfig)?
            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        
        let attachment = NSTextAttachment()
        attachment.image = symbolImage
        attachment.bounds = CGRect(x: 0, y: -2, width: symbolImage?.size.width ?? 0, height: symbolImage?.size.height ?? 0)
        
        let attributedString = NSMutableAttributedString(attachment: attachment)
        
        // Extract just the distance part (everything after " - ") or use the whole string if logic fails
        let cleanText: String
        if existingText.contains(" - ") {
            cleanText = existingText.components(separatedBy: " - ").last ?? existingText
        } else {
            cleanText = existingText
        }
        
        attributedString.append(NSAttributedString(string: " - \(cleanText)", attributes: [.font: UIFont.systemFont(ofSize: size, weight: .semibold)]))
        distanceLabel.attributedText = attributedString
    }
    
    private func setupAppearance() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        
        mapView.layer.cornerRadius = 12
        mapView.delegate = self
        
        tag1View.layer.masksToBounds = true
        terrainTagImageView.contentMode = .scaleAspectFit
        terrainTagImageView.layer.masksToBounds = true
        tag2View.layer.masksToBounds = true
        seasonTagImageView.contentMode = .scaleAspectFill
        seasonTagImageView.layer.masksToBounds = true
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.masksToBounds = false
    }
    
    func configure(migration: MigrationPrediction, hotspot: HotspotPrediction) {
        print("🎨 [PredictionDebug] Cell configure: \(hotspot.placeName), birds: \(hotspot.birdSpecies.count)")
        titleLabel.text = hotspot.placeName
        subtitleLabel.text = hotspot.locationDetail
        weekLabel.text = hotspot.weekNumber
        terrainTagLabel.text = hotspot.terrainTag
        seasonTagLabel.text = "\(hotspot.seasonTag) Migration"
        seasonTagImageView.image = UIImage(named: seasonAssetName(for: hotspot.seasonTag))
        tag2View.backgroundColor = seasonTagBackgroundColor(for: hotspot.seasonTag)
        
        // Attributed string for distance with SF Symbol
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let symbolImage = UIImage(systemName: "mappin.and.ellipse", withConfiguration: symbolConfig)?
            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        
        let attachment = NSTextAttachment()
        attachment.image = symbolImage
        // Adjust y offset to align with text
        attachment.bounds = CGRect(x: 0, y: -2, width: symbolImage?.size.width ?? 0, height: symbolImage?.size.height ?? 0)
        
        let attributedString = NSMutableAttributedString(attachment: attachment)
        attributedString.append(NSAttributedString(string: " - \(hotspot.distanceString)"))
        distanceLabel.attributedText = attributedString
        
        self.birdSpecies = hotspot.birdSpecies
        selectedBirdIndex = 0
        print("🎨 [PredictionDebug]   birdListCollectionView.reloadData() with \(self.birdSpecies.count) items")
        birdListCollectionView.reloadData()
        birdListCollectionView.layoutIfNeeded()
        alignToSelectedCard(animated: false)
        
        setupMap(
            pathCoordinates: migration.pathCoordinates,
            hotspotCenter: hotspot.centerCoordinate,
            birdPins: hotspot.hotspots,
            radiusKm: hotspot.pinRadiusKm
        )
    }
    
    private func setupMap(
        pathCoordinates: [CLLocationCoordinate2D],
        hotspotCenter: CLLocationCoordinate2D,
        birdPins: [HotspotBirdSpot],
        radiusKm: Double
    ) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        var mapRect = MKMapRect.null

        _ = pathCoordinates // Keep the input for future use; intentionally not rendered on this card.

        let radiusCircle = MKCircle(center: hotspotCenter, radius: radiusKm * 1000)
        mapView.addOverlay(radiusCircle)
        mapRect = mapRect.isNull ? radiusCircle.boundingMapRect : mapRect.union(radiusCircle.boundingMapRect)

        for annotation in deconflictedAnnotations(from: birdPins) {
            mapView.addAnnotation(annotation)
            let point = MKMapPoint(annotation.coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            mapRect = mapRect.isNull ? pointRect : mapRect.union(pointRect)
        }

        if !mapRect.isNull {
            let padding = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: false)
        }

        refreshPinSelectionState()
    }

    private func deconflictedAnnotations(from pins: [HotspotBirdSpot]) -> [BirdPinAnnotation] {
        let keyFor: (CLLocationCoordinate2D) -> String = { coordinate in
            let lat = String(format: "%.5f", coordinate.latitude)
            let lon = String(format: "%.5f", coordinate.longitude)
            return "\(lat),\(lon)"
        }

        var countByKey: [String: Int] = [:]
        var baseByKey: [String: CLLocationCoordinate2D] = [:]
        for pin in pins {
            let key = keyFor(pin.coordinate)
            countByKey[key, default: 0] += 1
            if baseByKey[key] == nil {
                baseByKey[key] = pin.coordinate
            }
        }

        var seenByKey: [String: Int] = [:]
        var result: [BirdPinAnnotation] = []
        result.reserveCapacity(pins.count)

        for (index, pin) in pins.enumerated() {
            let key = keyFor(pin.coordinate)
            let totalInGroup = countByKey[key] ?? 1
            let seen = seenByKey[key, default: 0]
            seenByKey[key] = seen + 1

            let coordinate: CLLocationCoordinate2D
            if totalInGroup > 1, let base = baseByKey[key] {
                let radiusMeters: Double = 60.0
                let metersPerDegreeLat: Double = 111_000.0
                let metersPerDegreeLon = max(1.0, cos(base.latitude * .pi / 180.0) * 111_000.0)
                let angle = (2.0 * Double.pi * Double(seen)) / Double(totalInGroup)
                let dLat = (radiusMeters * sin(angle)) / metersPerDegreeLat
                let dLon = (radiusMeters * cos(angle)) / metersPerDegreeLon
                coordinate = CLLocationCoordinate2D(
                    latitude: base.latitude + dLat,
                    longitude: base.longitude + dLon
                )
            } else {
                coordinate = pin.coordinate
            }

            result.append(
                BirdPinAnnotation(
                    coordinate: coordinate,
                    birdImageName: pin.birdImageName,
                    birdIndex: index,
                    pinColor: pinColor(for: pin.birdImageName, index: index)
                )
            )
        }

        return result
    }

    private func pinColor(for birdImageName: String, index: Int) -> UIColor {
        let palette: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange, .systemPink,
            .systemTeal, .systemIndigo, .systemMint, .systemBrown
        ]
        let hash = abs((birdImageName + "\(index)").hashValue)
        return palette[hash % palette.count]
    }

    private func refreshPinSelectionState() {
        for annotation in mapView.annotations {
            guard let birdAnnotation = annotation as? BirdPinAnnotation,
                  let view = mapView.view(for: birdAnnotation) as? MKMarkerAnnotationView else {
                continue
            }
            let isSelected = birdAnnotation.birdIndex == selectedBirdIndex
            applyPinStyle(view, baseColor: birdAnnotation.pinColor, isSelected: isSelected)
            view.layer.zPosition = isSelected ? 1000 : 0
            if isSelected {
                mapView.bringSubviewToFront(view)
            }
        }
    }

    private func applyPinStyle(_ view: MKMarkerAnnotationView, baseColor: UIColor, isSelected: Bool) {
        view.markerTintColor = baseColor
        view.glyphTintColor = .white

        let targetTransform: CGAffineTransform
        let targetAlpha: CGFloat
        if isSelected {
            targetTransform = CGAffineTransform(scaleX: 1.18, y: 1.18)
            targetAlpha = 1.0
            view.zPriority = .max
        } else {
            // Keep all pins visible, but make non-selected ones lighter/smaller.
            targetTransform = CGAffineTransform(scaleX: 0.82, y: 0.82)
            targetAlpha = 0.72
            view.zPriority = .defaultUnselected
        }

        if view.transform != targetTransform || view.alpha != targetAlpha {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                view.transform = targetTransform
                view.alpha = targetAlpha
            }
        }
    }
}

extension NewMigrationCollectionViewCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return birdSpecies.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: subcardViewCell.identifier, for: indexPath) as! subcardViewCell
        cell.configure(with: birdSpecies[indexPath.row])
        cell.setExpanded(indexPath.row == selectedBirdIndex)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        updateSelectedBirdIndex(indexPath.item, animated: true)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let itemHeight = nestedItemHeight(cardHeight: bounds.height)
        let isSelected = indexPath.item == selectedBirdIndex
        let width = isSelected ? expandedItemWidth(itemHeight: itemHeight) : compactItemWidth(itemHeight: itemHeight)
        return CGSize(width: width, height: itemHeight)
    }
    
    private func updateSelectedBirdIndex(_ newIndex: Int, animated: Bool) {
        guard !birdSpecies.isEmpty else { return }
        let clamped = min(max(newIndex, 0), birdSpecies.count - 1)
        let oldIndex = selectedBirdIndex
        guard clamped != oldIndex else {
            if animated {
                alignToSelectedCard(animated: true)
            }
            return
        }
        
        selectedBirdIndex = clamped
        birdListCollectionView.performBatchUpdates({
            birdListCollectionView.reloadItems(at: [IndexPath(item: oldIndex, section: 0), IndexPath(item: clamped, section: 0)])
        })
        
        refreshPinSelectionState()
        alignToSelectedCard(animated: animated)
    }
    
    private func alignToSelectedCard(animated: Bool) {
        guard !birdSpecies.isEmpty else { return }
        birdListCollectionView.layoutIfNeeded()
        let x = targetOffsetX(for: selectedBirdIndex)
        birdListCollectionView.setContentOffset(CGPoint(x: x, y: 0), animated: animated)
    }
    
    private func targetOffsetX(for index: Int) -> CGFloat {
        guard let layout = birdListCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return birdListCollectionView.contentOffset.x
        }
        
        let clamped = min(max(index, 0), birdSpecies.count - 1)
        let indexPath = IndexPath(item: clamped, section: 0)
        
        let rawX: CGFloat
        if clamped == birdSpecies.count - 1 {
            rawX = maxScrollableOffsetX()
        } else if let attributes = layout.layoutAttributesForItem(at: indexPath) {
            rawX = attributes.frame.minX - layout.sectionInset.left
        } else {
            rawX = birdListCollectionView.contentOffset.x
        }
        
        return clampOffsetX(rawX)
    }
    
    private func maxScrollableOffsetX() -> CGFloat {
        let maxX = birdListCollectionView.contentSize.width - birdListCollectionView.bounds.width + birdListCollectionView.contentInset.right
        let minX = -birdListCollectionView.contentInset.left
        return max(minX, maxX)
    }
    
    private func clampOffsetX(_ x: CGFloat) -> CGFloat {
        let minX = -birdListCollectionView.contentInset.left
        let maxX = maxScrollableOffsetX()
        return min(max(x, minX), maxX)
    }
    
    private func seasonAssetName(for season: String) -> String {
        if season == "Rainy" {
            return "Rainy "
        }
        return season
    }
    
    private func seasonTagBackgroundColor(for season: String) -> UIColor {
        switch season {
        case "Summer":
            return UIColor(red: 0.85, green: 0.95, blue: 0.45, alpha: 0.4) // light lime yellow
        case "Spring":
            return UIColor(red: 0.95, green: 0.60, blue: 0.80, alpha: 0.4) // light pink-magenta
        case "Autumn":
            return UIColor(red: 1.00, green: 0.70, blue: 0.45, alpha: 0.4) // light orange
        case "Winter":
            return UIColor.systemBlue.withAlphaComponent(0.4) // light system blue
        case "Rainy":
            return UIColor.systemGray.withAlphaComponent(0.4) // light gray
        default:
            return UIColor.systemGray5.withAlphaComponent(0.4)
        }
    }
}

extension NewMigrationCollectionViewCell: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let birdAnnotation = annotation as? BirdPinAnnotation else { return nil }

        let identifier = "BirdPinAnnotationView"
        let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        view.annotation = annotation
        view.canShowCallout = false
        view.glyphImage = UIImage(systemName: "bird.fill")
        view.displayPriority = .required
        view.collisionMode = .none
        view.clusteringIdentifier = nil
        view.titleVisibility = .hidden
        view.subtitleVisibility = .hidden
        applyPinStyle(view, baseColor: birdAnnotation.pinColor, isSelected: birdAnnotation.birdIndex == selectedBirdIndex)

        return view
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 3
            renderer.lineDashPattern = [2, 4]
            return renderer
        }
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.08)
            renderer.lineWidth = 1.5
            return renderer
        }
        return MKOverlayRenderer()
    }
}
