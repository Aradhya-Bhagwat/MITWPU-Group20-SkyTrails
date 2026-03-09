
import UIKit
import MapKit
import CoreLocation

class NewMigrationCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "NewMigrationCollectionViewCell"
    
    private struct TerrainInfo {
        let name: String
        let symbolName: String
        let color: UIColor
        let defaultImageName: String
    }
    
    private static var terrainCache: [String: TerrainInfo] = [:]
    private static var terrainImageCache: [String: UIImage] = [:]
    private var geocodingTask: Task<Void, Never>?
    
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        geocodingTask?.cancel()
        geocodingTask = nil
        terrainTagLabel.text = "Loading..."
        terrainTagImageView.image = UIImage(named: "Terrain_Remote")
        tag1View.backgroundColor = .systemGray5.withAlphaComponent(0.4)
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
        tag1View.layer.cornerRadius = tag1View.bounds.height / 2
        tag2View.layer.cornerRadius = tag2View.bounds.height / 2
        seasonTagImageView.layer.cornerRadius = seasonTagImageView.bounds.height / 2
        terrainTagImageView.layer.cornerRadius = terrainTagImageView.bounds.height / 2
    }
    
    private func updateNestedLayout() {
        let cardHeight = self.bounds.height
        let heightRatio = cardHeight / 440.0
        let titleSize = max(17, 17 * heightRatio)
        titleLabel.font = .systemFont(ofSize: titleSize, weight: .bold)
        let otherSize = max(12, 12 * heightRatio)
        subtitleLabel.font = .systemFont(ofSize: otherSize)
        weekLabel.font = .systemFont(ofSize: otherSize)
        terrainTagLabel.font = .systemFont(ofSize: otherSize, weight: .medium)
        seasonTagLabel.font = .systemFont(ofSize: otherSize, weight: .medium)
        updateDistanceLabelFont(size: otherSize)
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
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        let symbolImage = UIImage(systemName: "mappin.and.ellipse", withConfiguration: symbolConfig)?
            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        
        let attachment = NSTextAttachment()
        attachment.image = symbolImage
        attachment.bounds = CGRect(x: 0, y: -2, width: symbolImage?.size.width ?? 0, height: symbolImage?.size.height ?? 0)
        
        let attributedString = NSMutableAttributedString(attachment: attachment)
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
        titleLabel.text = hotspot.placeName
        subtitleLabel.text = hotspot.locationDetail
        weekLabel.text = hotspot.weekNumber
        terrainTagLabel.text = hotspot.terrainTag
        
        seasonTagLabel.text = "\(hotspot.seasonTag) Migration"
        seasonTagImageView.image = UIImage(named: seasonAssetName(for: hotspot.seasonTag))
        tag2View.backgroundColor = seasonTagBackgroundColor(for: hotspot.seasonTag)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let symbolImage = UIImage(systemName: "mappin.and.ellipse", withConfiguration: symbolConfig)?
            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        
        let attachment = NSTextAttachment()
        attachment.image = symbolImage
        attachment.bounds = CGRect(x: 0, y: -2, width: symbolImage?.size.width ?? 0, height: symbolImage?.size.height ?? 0)
        
        let attributedString = NSMutableAttributedString(attachment: attachment)
        attributedString.append(NSAttributedString(string: " - \(hotspot.distanceString)"))
        distanceLabel.attributedText = attributedString
        
        self.birdSpecies = hotspot.birdSpecies
        selectedBirdIndex = 0
        birdListCollectionView.reloadData()
        birdListCollectionView.layoutIfNeeded()
        alignToSelectedCard(animated: false)
        
        setupMap(
            pathCoordinates: migration.pathCoordinates,
            hotspotCenter: hotspot.centerCoordinate,
            areaOverlay: hotspot.areaOverlay,
            birdPins: hotspot.hotspots
        )
        fetchTerrain(for: hotspot.centerCoordinate)
    }
    
    private func fetchTerrain(for coordinate: CLLocationCoordinate2D) {
        let cacheKey = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        if let info = Self.terrainCache[cacheKey] {
            let image = Self.terrainImageCache[cacheKey] ?? UIImage(named: info.defaultImageName)
            applyTerrain(info, image: image)
            return
        }
        
        geocodingTask = Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard !Task.isCancelled else { return }
                
                let info = placemarks.first.map { classifyTerrain(from: $0) } 
                           ?? TerrainInfo(name: "Remote Area", symbolName: "mappin.circle", color: .systemGray, defaultImageName: "Terrain_Remote")
                
                Self.terrainCache[cacheKey] = info
                var finalImage = UIImage(named: info.defaultImageName)
                
                if #available(iOS 16.0, *) {
                    let request = MKLookAroundSceneRequest(coordinate: coordinate)
                    if let scene = try? await request.scene {
                        let options = MKLookAroundSnapshotter.Options()
                        options.size = CGSize(width: 120, height: 120)
                        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
                        if let snapshot = try? await snapshotter.snapshot {
                            finalImage = snapshot.image
                            Self.terrainImageCache[cacheKey] = finalImage
                        }
                    }
                }
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.applyTerrain(info, image: finalImage)
                }
            } catch {
                let fallback = TerrainInfo(name: "Remote Area", symbolName: "mappin.circle", color: .systemGray, defaultImageName: "Terrain_Remote")
                await MainActor.run {
                    self.applyTerrain(fallback, image: UIImage(named: fallback.defaultImageName))
                }
            }
        }
    }
    
    private func classifyTerrain(from placemark: CLPlacemark) -> TerrainInfo {
        let skyBlue = UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1.0)
        
        // Resilience against property name changes in future iOS
        let locality = placemark.locality
        let name = placemark.name ?? ""
        
        if let areas = placemark.areasOfInterest, !areas.isEmpty {
            let waterKeywords = ["ocean", "sea", "bay", "gulf", "lake", "river", "water"]
            if areas.contains(where: { area in waterKeywords.contains(where: { area.lowercased().contains($0) }) }) {
                return TerrainInfo(name: "Marine", symbolName: "waves.up.and.down", color: skyBlue, defaultImageName: "Terrain_Marine")
            }
        }
        
        if let interests = placemark.areasOfInterest, !interests.isEmpty {
            let forestKeywords = ["park", "forest", "nature", "reserve", "wilderness", "mountain", "wildlife", "rainforest"]
            let isRainforest = interests.contains { interest in
                forestKeywords.contains { keyword in
                    interest.lowercased().contains(keyword)
                }
            }
            if isRainforest {
                return TerrainInfo(name: "Rainforest", symbolName: "tree.fill", color: UIColor(red: 0.0, green: 0.6, blue: 0.45, alpha: 1.0), defaultImageName: "Terrain_Wilderness")
            }
        }
        
        if locality != nil || name.contains("St") || name.contains("Rd") || name.contains("Ave") {
            return TerrainInfo(name: "Residential", symbolName: "building.2.fill", color: skyBlue, defaultImageName: "Terrain_Residential")
        }
        
        return TerrainInfo(name: "General Land", symbolName: "map.fill", color: UIColor(red: 0.68, green: 0.84, blue: 0.19, alpha: 1.0), defaultImageName: "Terrain_Land")
    }
    
    private func applyTerrain(_ info: TerrainInfo, image: UIImage?) {
        terrainTagLabel.text = info.name
        terrainTagImageView.isHidden = false
        terrainTagImageView.alpha = 1.0
        terrainTagImageView.image = image
        terrainTagImageView.contentMode = .scaleAspectFill
        terrainTagImageView.clipsToBounds = true
        tag1View.backgroundColor = info.color.withAlphaComponent(0.4)
    }

    private func setupMap(
        pathCoordinates: [CLLocationCoordinate2D],
        hotspotCenter: CLLocationCoordinate2D,
        areaOverlay: HotspotAreaOverlay,
        birdPins: [HotspotBirdSpot]
    ) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        var mapRect = MKMapRect.null

        _ = pathCoordinates

        switch areaOverlay {
        case .polygon(let coordinates):
            guard coordinates.count >= 3 else { break }
            var polygonCoordinates = coordinates
            let polygon = MKPolygon(coordinates: &polygonCoordinates, count: polygonCoordinates.count)
            mapView.addOverlay(polygon)
            mapRect = mapRect.isNull ? polygon.boundingMapRect : mapRect.union(polygon.boundingMapRect)
        case .circle(let overlayRadiusKm):
            let radiusCircle = MKCircle(center: hotspotCenter, radius: overlayRadiusKm * 1000)
            mapView.addOverlay(radiusCircle)
            mapRect = mapRect.isNull ? radiusCircle.boundingMapRect : mapRect.union(radiusCircle.boundingMapRect)
        }

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
        let baseSeed = Double(abs(birdImageName.hashValue % 10_000)) / 10_000.0
        let hue = (baseSeed + (Double(index) * 0.61803398875)).truncatingRemainder(dividingBy: 1.0)
        return UIColor(
            hue: CGFloat(hue),
            saturation: 0.72,
            brightness: 0.90,
            alpha: 1.0
        )
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
        let bird = birdSpecies[indexPath.row]
        let accentColor = pinColor(for: bird.birdImageName, index: indexPath.row)
        cell.configure(with: bird, accentColor: accentColor)
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
            return UIColor(red: 0.85, green: 0.95, blue: 0.45, alpha: 0.4)
        case "Spring":
            return UIColor(red: 0.95, green: 0.60, blue: 0.80, alpha: 0.4)
        case "Autumn":
            return UIColor(red: 1.00, green: 0.70, blue: 0.45, alpha: 0.4)
        case "Winter":
            return UIColor.systemBlue.withAlphaComponent(0.4)
        case "Rainy":
            return UIColor.systemGray.withAlphaComponent(0.4)
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
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.75)
            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.10)
            renderer.lineWidth = 1.6
            return renderer
        }
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
