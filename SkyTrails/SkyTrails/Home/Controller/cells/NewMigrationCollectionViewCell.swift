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
    @IBOutlet weak var birdListCollectionView: UICollectionView!
    
    private var birdSpecies: [BirdSpeciesDisplay] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCollectionView()
        setupAppearance()
    }
    
    private func setupCollectionView() {
        birdListCollectionView.delegate = self
        birdListCollectionView.dataSource = self
        birdListCollectionView.register(UINib(nibName: subcardViewCell.identifier, bundle: Bundle(for: subcardViewCell.self)), forCellWithReuseIdentifier: subcardViewCell.identifier)
        
        let layout = SnappingFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        birdListCollectionView.collectionViewLayout = layout
        birdListCollectionView.showsHorizontalScrollIndicator = false
        birdListCollectionView.backgroundColor = .clear
        birdListCollectionView.decelerationRate = .fast
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateNestedLayout()
    }
    
    private func updateNestedLayout() {
        let cardHeight = self.bounds.height
        let cardWidth = self.bounds.width
        
        // 1. Scale Fonts
        let heightRatio = cardHeight / 440.0
        
        // Title: Min 17, max scales with height
        let titleSize = max(17, 17 * heightRatio)
        titleLabel.font = .systemFont(ofSize: titleSize, weight: .bold)
        
        // Others: Min 12, max scales with height
        let otherSize = max(12, 12 * heightRatio)
        subtitleLabel.font = .systemFont(ofSize: otherSize)
        weekLabel.font = .systemFont(ofSize: otherSize)
        
        // Distance label needs special handling for attributed string size
        updateDistanceLabelFont(size: otherSize)
        
        // 2. Scale Nested CollectionView Items
        if let layout = birdListCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            // Proportional height based on design ratio (90/440)
            var itemHeight = cardHeight * (90.0 / 440.0)
            var itemWidth = itemHeight * (25.0 / 9.0)
            
            // Cap width at 400px to maintain readability on large screens
            if itemWidth > 400 {
                itemWidth = 400
                itemHeight = itemWidth * (9.0 / 25.0)
            }
            
            let newSize = CGSize(width: itemWidth, height: itemHeight)
            if layout.itemSize != newSize {
                layout.itemSize = newSize
                layout.invalidateLayout()
            }
        }
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
        tag2View.layer.cornerRadius = 8
        
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
        print("🎨 [PredictionDebug]   birdListCollectionView.reloadData() with \(self.birdSpecies.count) items")
        birdListCollectionView.reloadData()
        
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

extension NewMigrationCollectionViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return birdSpecies.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: subcardViewCell.identifier, for: indexPath) as! subcardViewCell
        cell.configure(with: birdSpecies[indexPath.row])
        return cell
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
