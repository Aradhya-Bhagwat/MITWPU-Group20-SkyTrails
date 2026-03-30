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
        let titleRatio: CGFloat = 17.0 / 200.0
        let detailRatio: CGFloat = 12.0 / 200.0
        let titleSize = min(currentWidth * titleRatio, 24)
        let detailSize = min(currentWidth * detailRatio, 18)

        titleLabel.font = .systemFont(ofSize: titleSize, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: detailSize, weight: .regular)
        subtitleLabel.textColor = .black
        
        if #available(iOS 15.0, *) {
            weekButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: detailSize, weight: .semibold)
                return outgoing
            }
        } else {
            weekButton.titleLabel?.font = .systemFont(ofSize: detailSize, weight: .semibold)
        }

        terrainTagLabel.font = .systemFont(ofSize: detailSize, weight: .bold)
        seasonTagLabel.font = .systemFont(ofSize: detailSize, weight: .bold)
        terrainTagIconSizeConstraint.constant = detailSize
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

    private func resolvedBirdPins(
        for species: [BirdSpeciesDisplay],
        from rawPins: [HotspotBirdSpot],
        fallbackCoordinate: CLLocationCoordinate2D
    ) -> [HotspotBirdSpot] {
        var pinsByImageName: [String: [HotspotBirdSpot]] = [:]
        for pin in rawPins {
            pinsByImageName[pin.birdImageName, default: []].append(pin)
        }

        return species.map { bird in
            if var matchingPins = pinsByImageName[bird.birdImageName], !matchingPins.isEmpty {
                let matchedPin = matchingPins.removeFirst()
                pinsByImageName[bird.birdImageName] = matchingPins
                return matchedPin
            }

            return HotspotBirdSpot(
                coordinate: fallbackCoordinate,
                birdImageName: bird.birdImageName
            )
        }
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
        setupWeekButton(currentWeek: hotspot.weekNumber)
        
        terrainTagLabel.text = hotspot.terrainTag
        
        seasonTagLabel.text = "\(hotspot.seasonTag) Migration"
        applySeasonAppearance(for: hotspot.seasonTag)
        
        // Initial filter: All 3 weeks
        filterBirds(for: nil)
        
        birdListCollectionView.reloadData()
        birdListCollectionView.layoutIfNeeded()
        alignToSelectedCard(animated: false)

        let birdPins = resolvedBirdPins(
            for: self.birdSpecies,
            from: hotspot.hotspots,
            fallbackCoordinate: hotspot.centerCoordinate
        )
        
        setupMap(
            pathCoordinates: migration.pathCoordinates,
            hotspotCenter: hotspot.centerCoordinate,
            areaOverlay: hotspot.areaOverlay,
            birdPins: birdPins
        )
        fetchTerrain(for: hotspot.centerCoordinate)
    }

    private func setupWeekButton(currentWeek: String) {
        let weekNumber = Int(currentWeek.replacingOccurrences(of: "Week ", with: "")) ?? 0
        
        let allWeeksAction = UIAction(title: "All Weeks") { [weak self] _ in
            self?.filterBirds(for: nil)
            self?.weekButton.setTitle("All Weeks", for: .normal)
        }
        
        let currentWeekAction = UIAction(title: "Week \(weekNumber)") { [weak self] _ in
            self?.filterBirds(for: weekNumber)
            self?.weekButton.setTitle("Week \(weekNumber)", for: .normal)
        }
        
        let nextWeekAction = UIAction(title: "Week \(weekNumber + 1)") { [weak self] _ in
            self?.filterBirds(for: weekNumber + 1)
            self?.weekButton.setTitle("Week \(weekNumber + 1)", for: .normal)
        }
        
        let thirdWeekAction = UIAction(title: "Week \(weekNumber + 2)") { [weak self] _ in
            self?.filterBirds(for: weekNumber + 2)
            self?.weekButton.setTitle("Week \(weekNumber + 2)", for: .normal)
        }
        
        weekButton.menu = UIMenu(title: "Select Week", children: [allWeeksAction, currentWeekAction, nextWeekAction, thirdWeekAction])
        weekButton.showsMenuAsPrimaryAction = true
        weekButton.setTitle("All Weeks", for: .normal)
        
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
        if let week = week {
            let weekString = "Week \(week)"
            birdSpecies = fullBirdSpecies.filter { $0.weekNumber == weekString }
        } else {
            birdSpecies = fullBirdSpecies
        }
        selectedBirdIndex = 0
        birdListCollectionView.reloadData()
        
        // Update map pins when filtered
        if let hotspot = currentHotspot {
            let birdPins = resolvedBirdPins(
                for: self.birdSpecies,
                from: hotspot.hotspots,
                fallbackCoordinate: hotspot.centerCoordinate
            )
            
            // Only update annotations to avoid full map reset
            mapView.removeAnnotations(mapView.annotations)
            for annotation in deconflictedAnnotations(from: birdPins) {
                mapView.addAnnotation(annotation)
            }
            refreshPinSelectionState()
        }
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
                await MainActor.run { self.applyTerrain(info, image: finalImage) }
            } catch {
                let fallback = TerrainInfo(name: "Remote Area", symbolName: "mappin.circle", color: .systemGray, defaultImageName: "Terrain_Remote")
                await MainActor.run { self.applyTerrain(fallback, image: UIImage(named: fallback.defaultImageName)) }
            }
        }
    }
    
    private func classifyTerrain(from placemark: CLPlacemark) -> TerrainInfo {
        let skyBlue = UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1.0)
        let name = placemark.name ?? ""
        
        if let areas = placemark.areasOfInterest, !areas.isEmpty {
            let waterKeywords = ["ocean", "sea", "bay", "gulf", "lake", "river", "water"]
            if areas.contains(where: { area in waterKeywords.contains(where: { area.lowercased().contains($0) }) }) {
                return TerrainInfo(name: "Marine", symbolName: "waves.up.and.down", color: skyBlue, defaultImageName: "Terrain_Marine")
            }
            
            let forestKeywords = ["park", "forest", "nature", "reserve", "wilderness", "mountain", "wildlife", "rainforest"]
            if areas.contains(where: { area in forestKeywords.contains(where: { area.lowercased().contains($0) }) }) {
                return TerrainInfo(name: "Rainforest", symbolName: "tree.fill", color: UIColor(red: 0.0, green: 0.6, blue: 0.45, alpha: 1.0), defaultImageName: "Terrain_Wilderness")
            }
        }
        
        if placemark.locality != nil || name.contains("St") || name.contains("Rd") || name.contains("Ave") {
            return TerrainInfo(name: "Residential", symbolName: "building.2.fill", color: skyBlue, defaultImageName: "Terrain_Residential")
        }
        
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

    private func setupMap(pathCoordinates: [CLLocationCoordinate2D], hotspotCenter: CLLocationCoordinate2D, areaOverlay: HotspotAreaOverlay, birdPins: [HotspotBirdSpot]) {
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

        for annotation in deconflictedAnnotations(from: birdPins) {
            mapView.addAnnotation(annotation)
            let point = MKMapPoint(annotation.coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            mapRect = mapRect.isNull ? pointRect : mapRect.union(pointRect)
        }

        if !mapRect.isNull {
            let padding = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: true)
        }

        refreshPinSelectionState()
    }

    private func deconflictedAnnotations(from pins: [HotspotBirdSpot]) -> [BirdPinAnnotation] {
        let keyFor: (CLLocationCoordinate2D) -> String = { "\(String(format: "%.5f", $0.latitude)),\(String(format: "%.5f", $0.longitude))" }
        var countByKey: [String: Int] = [:]
        var baseByKey: [String: CLLocationCoordinate2D] = [:]
        for pin in pins {
            let key = keyFor(pin.coordinate)
            countByKey[key, default: 0] += 1
            if baseByKey[key] == nil { baseByKey[key] = pin.coordinate }
        }

        var seenByKey: [String: Int] = [:]
        return pins.enumerated().map { (index, pin) in
            let key = keyFor(pin.coordinate)
            let totalInGroup = countByKey[key] ?? 1
            let seen = seenByKey[key, default: 0]
            seenByKey[key] = seen + 1

            let coordinate: CLLocationCoordinate2D
            if totalInGroup > 1, let base = baseByKey[key] {
                let angle = (2.0 * .pi * Double(seen)) / Double(totalInGroup)
                let dLat = (60.0 * sin(angle)) / 111_000.0
                let dLon = (60.0 * cos(angle)) / max(1.0, cos(base.latitude * .pi / 180.0) * 111_000.0)
                coordinate = CLLocationCoordinate2D(latitude: base.latitude + dLat, longitude: base.longitude + dLon)
            } else {
                coordinate = pin.coordinate
            }

            return BirdPinAnnotation(coordinate: coordinate, birdImageName: pin.birdImageName, birdIndex: index, pinColor: pinColor(for: pin.birdImageName, index: index))
        }
    }

    private func pinColor(for birdImageName: String, index: Int) -> UIColor {
        let hue = (Double(abs(birdImageName.hashValue % 10_000)) / 10_000.0 + (Double(index) * 0.61803398875)).truncatingRemainder(dividingBy: 1.0)
        return UIColor(hue: CGFloat(hue), saturation: 0.72, brightness: 0.90, alpha: 1.0)
    }

    private func refreshPinSelectionState() {
        for annotation in mapView.annotations {
            guard let birdAnnotation = annotation as? BirdPinAnnotation,
                  let view = mapView.view(for: birdAnnotation) as? MKMarkerAnnotationView else { continue }
            let isSelected = birdAnnotation.birdIndex == selectedBirdIndex
            applyPinStyle(view, baseColor: birdAnnotation.pinColor, isSelected: isSelected)
            if isSelected { 
                view.layer.zPosition = 1000
                mapView.setCenter(birdAnnotation.coordinate, animated: true)
            } else {
                view.layer.zPosition = 0
            }
        }
    }

    private func applyPinStyle(_ view: MKMarkerAnnotationView, baseColor: UIColor, isSelected: Bool) {
        view.markerTintColor = baseColor
        view.glyphTintColor = .white
        let scale: CGFloat = isSelected ? 1.25 : 0.82
        let alpha: CGFloat = isSelected ? 1.0 : 0.72
        view.zPriority = isSelected ? .max : .defaultUnselected

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction]) {
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.alpha = alpha
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
        cell.configure(with: bird, accentColor: pinColor(for: bird.birdImageName, index: indexPath.row))
        cell.setExpanded(indexPath.row == selectedBirdIndex)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
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
        guard let birdAnnotation = annotation as? BirdPinAnnotation else { return nil }
        let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "BirdPinAnnotationView") as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "BirdPinAnnotationView")
        view.glyphImage = UIImage(systemName: "bird.fill")
        view.displayPriority = .required
        applyPinStyle(view, baseColor: birdAnnotation.pinColor, isSelected: birdAnnotation.birdIndex == selectedBirdIndex)
        return view
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
