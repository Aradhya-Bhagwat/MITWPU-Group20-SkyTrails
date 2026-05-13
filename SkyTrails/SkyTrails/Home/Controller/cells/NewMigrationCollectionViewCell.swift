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
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var weekButton: UIButton!
    @IBOutlet weak var terrainTagImageView: UIImageView!
    @IBOutlet weak var terrainTagLabel: UILabel!
    @IBOutlet weak var terrainTagIconSizeConstraint: NSLayoutConstraint!
    @IBOutlet weak var seasonTagImageView: UIImageView!
    @IBOutlet weak var seasonTagLabel: UILabel!
    @IBOutlet weak var birdListCollectionView: UICollectionView!
    
    private var fullBirdSpecies: [BirdSpeciesDisplay] = []
    private var birdSpecies: [BirdSpeciesDisplay] = []
    private var currentHotspot: HotspotPrediction?
    private var selectedBirdIndex: Int = 0
    var selectedWeek: Int?
    private var hasInstalledAdaptiveConstraints = false
    private let expandedWidthRatio: CGFloat = 25.0 / 9.0
    private let compactWidthRatio: CGFloat = 5.0 / 6.0
    private let nestedItemHeightRatio: CGFloat = 90.0 / 440.0

    private final class LocationPinAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        init(coordinate: CLLocationCoordinate2D) {
            self.coordinate = coordinate
            super.init()
        }
    }

    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCollectionView()
        setupAppearance()
        setupTextLayoutBehavior()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        geocodingTask?.cancel()
        geocodingTask = nil
        terrainTagLabel.text = "Loading..."
        terrainTagImageView.image = UIImage(named: "Terrain_Remote")
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
        terrainTagImageView.layer.cornerRadius = terrainTagImageView.bounds.height / 2
    }
    
    // Updates font sizes and item dimensions based on card height
    private func updateNestedLayout() {
        let cardHeight = self.bounds.height
        let currentWidth = self.bounds.width
        installAdaptiveConstraintsIfNeeded()

        let widthScale = currentWidth / 361.0
        let heightScale = cardHeight / 440.0
        let contentScale = min(max(min(widthScale, heightScale), 0.9), 1.2)
        let titleSize = min(max(17.0 * contentScale, 16.0), 21.0)
        let detailSize = min(max(12.0 * contentScale, 11.0), 14.0)

        titleLabel.font = .systemFont(ofSize: titleSize, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: detailSize, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        
        if #available(iOS 15.0, *) {
            weekButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: detailSize, weight: .semibold)
                return outgoing
            }
            weekButton.configuration?.imagePadding = max(4, detailSize * 0.45)
            weekButton.configuration?.contentInsets = NSDirectionalEdgeInsets(
                top: max(4, detailSize * 0.35),
                leading: max(10, detailSize * 0.85),
                bottom: max(4, detailSize * 0.35),
                trailing: max(10, detailSize * 0.85)
            )
        } else {
            weekButton.titleLabel?.font = .systemFont(ofSize: detailSize, weight: .semibold)
        }

        terrainTagLabel.font = .systemFont(ofSize: detailSize, weight: .bold)
        seasonTagLabel.font = .systemFont(ofSize: detailSize, weight: .bold)
        terrainTagIconSizeConstraint.constant = detailSize
        if let currentHotspot = currentHotspot {
            applySeasonAppearance(for: currentHotspot.seasonTag)
        }

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
        return (cardHeight * nestedItemHeightRatio) + 27
    }
    
    private func expandedItemWidth(itemHeight: CGFloat) -> CGFloat {
        return min(itemHeight * expandedWidthRatio, 400)
    }
    
    private func compactItemWidth(itemHeight: CGFloat) -> CGFloat {
        return itemHeight * compactWidthRatio
    }

    private func setupTextLayoutBehavior() {
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.9
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        terrainTagLabel.numberOfLines = 1
        terrainTagLabel.lineBreakMode = .byTruncatingTail
        terrainTagLabel.adjustsFontSizeToFitWidth = true
        terrainTagLabel.minimumScaleFactor = 0.85
        seasonTagLabel.numberOfLines = 1
        seasonTagLabel.lineBreakMode = .byTruncatingTail
        seasonTagLabel.adjustsFontSizeToFitWidth = true
        seasonTagLabel.minimumScaleFactor = 0.85

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        terrainTagImageView.setContentHuggingPriority(.required, for: .horizontal)
        terrainTagImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        terrainTagLabel.setContentHuggingPriority(.required, for: .horizontal)
        terrainTagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        seasonTagLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        weekButton.setContentHuggingPriority(.required, for: .horizontal)
        weekButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        weekButton.titleLabel?.adjustsFontSizeToFitWidth = true
        weekButton.titleLabel?.minimumScaleFactor = 0.85
    }

    private func installAdaptiveConstraintsIfNeeded() {
        guard !hasInstalledAdaptiveConstraints else { return }
        hasInstalledAdaptiveConstraints = true

        NSLayoutConstraint.activate([
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: terrainTagImageView.leadingAnchor, constant: -8),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12)
        ])
    }



    private func setupAppearance() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        
        mapView.layer.cornerRadius = 12
        mapView.delegate = self
        
        terrainTagImageView.contentMode = .scaleAspectFit
        terrainTagImageView.layer.masksToBounds = true
        seasonTagImageView.contentMode = .scaleAspectFit
        seasonTagImageView.layer.masksToBounds = true
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.masksToBounds = false
    }
    
    // populates UI with migration and hotspot data
    func configure(migration: MigrationPrediction, hotspot: HotspotPrediction) {
        self.currentHotspot = hotspot
        titleLabel.text = hotspot.placeName
        subtitleLabel.text = hotspot.locationDetail
        
        self.fullBirdSpecies = hotspot.birdSpecies
        setupWeekButton(weeks: hotspot.allWeeks)
        
        terrainTagLabel.text = hotspot.terrainTag
        
        seasonTagLabel.text = "\(hotspot.seasonTag) Migration"
        applySeasonAppearance(for: hotspot.seasonTag)
        
        // Initial filter: All weeks
        filterBirds(for: hotspot.allWeeks.first)
        
        birdListCollectionView.reloadData()
        birdListCollectionView.layoutIfNeeded()
        alignToSelectedCard(animated: false)


        
        setupMap(
            pathCoordinates: migration.pathCoordinates,
            hotspotCenter: hotspot.centerCoordinate,
            areaOverlay: hotspot.areaOverlay
        )

        fetchTerrain(for: hotspot.centerCoordinate)
    }

    private func setupWeekButton(weeks: [Int]) {
        guard !weeks.isEmpty else { return }
        
        let allWeeksAction = UIAction(title: "All Weeks") { [weak self] _ in
            self?.filterBirds(for: nil)
            self?.weekButton.setTitle("All Weeks", for: .normal)
        }
        
        var weekActions: [UIAction] = []
        for week in weeks {
            let action = UIAction(title: "Week \(week)") { [weak self] _ in
                self?.filterBirds(for: week)
                self?.weekButton.setTitle("Week \(week)", for: .normal)
            }
            weekActions.append(action)
        }
        
        let menu = UIMenu(
            title: "Filter by Week",
            children: [allWeeksAction] + weekActions
        )
        weekButton.menu = menu
        weekButton.showsMenuAsPrimaryAction = true
        weekButton.setTitle("Week \(weeks.first ?? 0)", for: .normal)
        
        // Style the button to look more like a dropdown
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.gray()
            config.image = UIImage(systemName: "chevron.down")
            config.imagePlacement = .trailing
            config.imagePadding = 8
            config.baseForegroundColor = .black
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
            weekButton.configuration = config
        } else {
            weekButton.setTitleColor(.black, for: .normal)
            weekButton.backgroundColor = .systemGray6
            weekButton.layer.cornerRadius = 12
        }
    }

    private func filterBirds(for week: Int?) {
        self.selectedWeek = week
        if let week = week {
            // Filter to only birds present in this week
            // Use that week's specific sightability score
            birdSpecies = fullBirdSpecies.compactMap { bird in
                let weekKey = "\(week)"
                guard let weekScore = bird.weekScores?[weekKey],
                      weekScore > 0
                else { return nil }
                
                // Return bird with this week's specific score
                // not the peak score
                return BirdSpeciesDisplay(
                    birdName: bird.birdName,
                    birdImageName: bird.birdImageName,
                    statusBadge: bird.statusBadge,
                    sightabilityPercent: weekScore,
                    weekNumber: "Week \(week)",
                    residencyStatus: bird.residencyStatus,
                    ebirdSpeciesCode: bird.ebirdSpeciesCode,
                    peakWeek: bird.peakWeek,
                    weekScores: bird.weekScores,
                    allWeekNumbers: bird.allWeekNumbers
                )
            }
        } else {
            // All weeks — show peak sightability
            birdSpecies = fullBirdSpecies
        }
        selectedBirdIndex = 0
        birdListCollectionView.reloadData()
    }
    
    // Background task to resolve terrain information and scene snapshots
    private func fetchTerrain(for coordinate: CLLocationCoordinate2D) {
        let cacheKey = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        if let info = Self.terrainCache[cacheKey] {
            let image = Self.terrainImageCache[cacheKey] ?? UIImage(named: info.defaultImageName)
            applyTerrain(info, image: image)
            return
        }
        
        geocodingTask = Task {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                let mapItems = try await request.mapItems
                guard !Task.isCancelled else { return }
                
                let info = mapItems.first.map { classifyTerrain(from: $0) }
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
                await MainActor.run { self.applyTerrain(info, image: finalImage) }
            } catch {
                let fallback = TerrainInfo(name: "Remote Area", symbolName: "mappin.circle", color: .systemGray, defaultImageName: "Terrain_Remote")
                await MainActor.run { self.applyTerrain(fallback, image: UIImage(named: fallback.defaultImageName)) }
            }
        }
    }
    
    private func classifyTerrain(from mapItem: MKMapItem) -> TerrainInfo {
        let skyBlue = UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1.0)
        let name = mapItem.name ?? ""
        let addressText = [
            mapItem.address?.shortAddress,
            mapItem.address?.fullAddress,
            mapItem.addressRepresentations?.cityWithContext,
            mapItem.addressRepresentations?.regionName
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
        let searchableText = "\(name.lowercased()) \(addressText)"
        let category = mapItem.pointOfInterestCategory

        // 1. Water / Marine (Highest priority)
        let waterKeywords = ["ocean", "sea", "bay", "gulf", "lake", "river", "water", "coast", "beach", "marina", "reservoir"]
        if waterKeywords.contains(where: { searchableText.contains($0) }) || category == .beach || category == .marina {
            return TerrainInfo(name: "Marine", symbolName: "waves.up.and.down", color: skyBlue, defaultImageName: "Terrain_Marine")
        }

        // 2. Nature Reserve / Forest
        let forestKeywords = ["park", "forest", "nature", "reserve", "wilderness", "mountain", "wildlife", "rainforest", "woods", "sanctuary", "national park"]
        if forestKeywords.contains(where: { searchableText.contains($0) }) || category == .park || category == .nationalPark {
            return TerrainInfo(name: "Nature Reserve", symbolName: "tree.fill", color: UIColor(red: 0.0, green: 0.6, blue: 0.45, alpha: 1.0), defaultImageName: "Terrain_Wilderness")
        }

        // 3. Grassland / Open Field
        let grasslandKeywords = ["farm", "field", "meadow", "grass", "plain", "valley", "ranch", "garden", "greenery", "campus", "golf", "open space"]
        if grasslandKeywords.contains(where: { searchableText.contains($0) }) || category == .university {
            return TerrainInfo(name: "Grassland", symbolName: "leaf.fill", color: UIColor(red: 0.68, green: 0.84, blue: 0.19, alpha: 1.0), defaultImageName: "Terrain_Land")
        }

        // 4. Residential / Urban (Lower priority than nature)
        if category == .hospital || category == .restaurant || category == .hotel || category == .museum || category == .theater ||
            searchableText.contains(" st") || searchableText.contains(" rd") || searchableText.contains(" ave") || searchableText.contains(" buildings") {
            return TerrainInfo(name: "Residential", symbolName: "building.2.fill", color: skyBlue, defaultImageName: "Terrain_Residential")
        }
        
        // 5. General Land / Fallback
        return TerrainInfo(name: "General Land", symbolName: "map.fill", color: UIColor(red: 0.68, green: 0.84, blue: 0.19, alpha: 1.0), defaultImageName: "Terrain_Land")
    }
    
    private func applyTerrain(_ info: TerrainInfo, image: UIImage?) {
        terrainTagLabel.text = info.name
        terrainTagImageView.isHidden = false
        terrainTagImageView.image = image
        terrainTagImageView.contentMode = .scaleAspectFill
        terrainTagImageView.clipsToBounds = true
    
    }

    private func applySeasonAppearance(for season: String) {
        let appearance = seasonSymbolAppearance(for: season)
        let pointSize = seasonTagLabel.font.pointSize
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        seasonTagImageView.image = UIImage(systemName: appearance.symbolName, withConfiguration: config)?
            .withTintColor(appearance.color, renderingMode: .alwaysOriginal)
        seasonTagImageView.tintColor = appearance.color
        seasonTagImageView.contentMode = .scaleAspectFit
        seasonTagViewTransparency()
    }

    private func seasonTagViewTransparency() {
        seasonTagLabel.textColor = .label
    }

    private func seasonSymbolAppearance(for season: String) -> (symbolName: String, color: UIColor) {
        switch season {
        case "Summer":
            return ("sun.max.fill", UIColor(red: 0.95, green: 0.64, blue: 0.12, alpha: 1.0))
        case "Winter":
            return ("snowflake", UIColor(red: 0.20, green: 0.48, blue: 0.92, alpha: 1.0))
        case "Rainy":
            return ("cloud.rain.fill", UIColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1.0))
        case "Autumn":
            return ("leaf.fill", UIColor(red: 0.68, green: 0.38, blue: 0.12, alpha: 1.0))
        case "Spring":
            return ("camera.macro", UIColor(red: 0.86, green: 0.29, blue: 0.45, alpha: 1.0))
        default:
            return ("circle.fill", .systemGray)
        }
    }

    private func setupMap(pathCoordinates: [CLLocationCoordinate2D], hotspotCenter: CLLocationCoordinate2D, areaOverlay: HotspotAreaOverlay) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        var mapRect = MKMapRect.null

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

        let centerPin = LocationPinAnnotation(coordinate: hotspotCenter)
        mapView.addAnnotation(centerPin)
        
        let point = MKMapPoint(hotspotCenter)
        let pointRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
        mapRect = mapRect.isNull ? pointRect : mapRect.union(pointRect)


        if !mapRect.isNull {
            let padding = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: true)
        }

        refreshPinSelectionState()
    }



    private func refreshPinSelectionState() {
        // No-op: we only have one center pin now
    }

}

extension NewMigrationCollectionViewCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return birdSpecies.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: subcardViewCell.identifier, for: indexPath) as! subcardViewCell
        let bird = birdSpecies[indexPath.row]
        cell.configure(with: bird)
        cell.setExpanded(indexPath.row == selectedBirdIndex)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        updateSelectedBirdIndex(indexPath.item, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemHeight = nestedItemHeight(cardHeight: bounds.height)
        let width = indexPath.item == selectedBirdIndex ? expandedItemWidth(itemHeight: itemHeight) : compactItemWidth(itemHeight: itemHeight)
        return CGSize(width: width, height: itemHeight)
    }
    
    private func updateSelectedBirdIndex(_ newIndex: Int, animated: Bool) {
        let oldIndex = selectedBirdIndex
        guard !birdSpecies.isEmpty, newIndex != oldIndex else {
            if animated { alignToSelectedCard(animated: true) }
            return
        }
        
        selectedBirdIndex = min(max(newIndex, 0), birdSpecies.count - 1)
        birdListCollectionView.performBatchUpdates({
            birdListCollectionView.reloadItems(at: [IndexPath(item: oldIndex, section: 0), IndexPath(item: selectedBirdIndex, section: 0)])
        })
        
        refreshPinSelectionState()
        alignToSelectedCard(animated: animated)
    }
    
    private func alignToSelectedCard(animated: Bool) {
        guard !birdSpecies.isEmpty else { return }
        birdListCollectionView.layoutIfNeeded()
        birdListCollectionView.setContentOffset(CGPoint(x: targetOffsetX(for: selectedBirdIndex), y: 0), animated: animated)
    }
    
    private func targetOffsetX(for index: Int) -> CGFloat {
        guard let layout = birdListCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return birdListCollectionView.contentOffset.x }
        let clamped = min(max(index, 0), birdSpecies.count - 1)
        let rawX = clamped == birdSpecies.count - 1 ? maxScrollableOffsetX() : (layout.layoutAttributesForItem(at: IndexPath(item: clamped, section: 0))?.frame.minX ?? 0) - layout.sectionInset.left
        return max(-birdListCollectionView.contentInset.left, min(rawX, maxScrollableOffsetX()))
    }
    
    private func maxScrollableOffsetX() -> CGFloat {
        return max(-birdListCollectionView.contentInset.left, birdListCollectionView.contentSize.width - birdListCollectionView.bounds.width + birdListCollectionView.contentInset.right)
    }
    
}

extension NewMigrationCollectionViewCell: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is LocationPinAnnotation {
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "CenterPin") as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "CenterPin")
            view.markerTintColor = .systemTeal
            view.glyphImage = UIImage(systemName: "mappin.and.ellipse")
            view.glyphTintColor = .white
            return view
        }
        return nil
    }


    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let r = MKPolygonRenderer(polygon: polygon)
            r.strokeColor = UIColor.systemBlue.withAlphaComponent(0.75); r.fillColor = UIColor.systemBlue.withAlphaComponent(0.10); r.lineWidth = 1.6
            return r
        }
        if let polyline = overlay as? MKPolyline {
            let r = MKPolylineRenderer(polyline: polyline)
            r.strokeColor = .systemBlue; r.lineWidth = 3; r.lineDashPattern = [2, 4]
            return r
        }
        if let circle = overlay as? MKCircle {
            let r = MKCircleRenderer(circle: circle)
            r.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7); r.fillColor = UIColor.systemBlue.withAlphaComponent(0.08); r.lineWidth = 1.5
            return r
        }
        return MKOverlayRenderer()
    }
}
