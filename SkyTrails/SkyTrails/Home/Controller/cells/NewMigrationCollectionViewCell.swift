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
    @IBOutlet weak var tag2View: UIView!
    @IBOutlet weak var seasonTagImageView: UIImageView!
    @IBOutlet weak var seasonTagLabel: UILabel!
    @IBOutlet weak var birdListCollectionView: UICollectionView!
    
    private var birdSpecies: [BirdSpeciesDisplay] = []
    private var selectedBirdIndex: Int = 0
    private let expandedWidthRatio: CGFloat = 25.0 / 9.0
    private let compactWidthRatio: CGFloat = 5.0 / 6.0
    private let nestedItemHeightRatio: CGFloat = 90.0 / 440.0
    
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
        
        tag1View.layer.cornerRadius = 8
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
        
        setupMapPath(coordinates: migration.pathCoordinates)
    }
    
    private func setupMapPath(coordinates: [CLLocationCoordinate2D]) {
        mapView.removeOverlays(mapView.overlays)
        guard !coordinates.isEmpty else { return }
        
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Zoom to polyline
        let padding = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: padding, animated: true)
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
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 3
            renderer.lineDashPattern = [2, 4]
            return renderer
        }
        return MKOverlayRenderer()
    }
}
