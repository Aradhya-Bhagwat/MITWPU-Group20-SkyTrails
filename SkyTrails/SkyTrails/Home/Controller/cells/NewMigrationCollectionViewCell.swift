
import UIKit
import MapKit
import CoreLocation

class NewMigrationCollectionViewCell: UICollectionViewCell {

    static let identifier = "NewMigrationCollectionViewCell"

    // MARK: - Types

    private struct TerrainInfo {
        let name: String
        let symbolName: String
        let color: UIColor
        let defaultImageName: String
    }

    // MARK: - Data Properties

    private static var terrainCache: [String: TerrainInfo] = [:]
    private static var terrainImageCache: [String: UIImage] = [:]
    private var geocodingTask: Task<Void, Never>?
    
    private var birdSpecies: [BirdSpeciesDisplay] = []
    private var currentHotspot: HotspotPrediction?
    private var selectedBirdIndex: Int = 0
    var selectedWeek: Int?

    // MARK: - UI Components

    private let mainContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 32
        v.layer.masksToBounds = true
        v.layer.borderWidth = 1.0
        v.layer.borderColor = UIColor.label.withAlphaComponent(0.08).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let mapView: MKMapView = {
        let m = MKMapView()
        m.isUserInteractionEnabled = false
        m.translatesAutoresizingMaskIntoConstraints = false
        return m
    }()

    private let mapDimmingOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = .black.withAlphaComponent(0.25)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let yourAreaLabel: UILabel = {
        let l = UILabel()
        l.text = "Your Area"
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .white.withAlphaComponent(0.8)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cityNameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 36, weight: .bold)
        l.textColor = .white
        l.shadowColor = .black.withAlphaComponent(0.3)
        l.shadowOffset = CGSize(width: 0, height: 2)
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let terrainPill: UIView = {
        let v = UIView()
        v.backgroundColor = .black.withAlphaComponent(0.3)
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let terrainIcon: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.layer.cornerRadius = 10
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let terrainLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let viewInMapsButton: UIButton = {
        let b = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "location.north.fill")
        config.title = "Maps"
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .black.withAlphaComponent(0.35)
        config.baseForegroundColor = .white
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        b.configuration = config
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let glassInfoBar: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        v.layer.cornerRadius = 20
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let infoStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fillEqually
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let birdsHeaderStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .center
        s.spacing = 10
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let birdsIcon: UIImageView = {
        let v = UIImageView(image: UIImage(systemName: "bird.fill"))
        v.tintColor = .systemTeal
        v.contentMode = .scaleAspectFit
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let birdsTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Birds in Your Area"
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let birdListCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .normal
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupCollectionView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupCollectionView()
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.addSubview(mainContainer)
        
        mainContainer.addSubview(mapView)
        mapView.addSubview(mapDimmingOverlay)
        
        mainContainer.addSubview(cityNameLabel)
        mainContainer.addSubview(terrainPill)
        terrainPill.addSubview(terrainIcon)
        terrainPill.addSubview(terrainLabel)
        mainContainer.addSubview(viewInMapsButton)
        
        mainContainer.addSubview(glassInfoBar)
        glassInfoBar.contentView.addSubview(infoStack)
        
        mainContainer.addSubview(birdsHeaderStack)
        birdsHeaderStack.addArrangedSubview(birdsIcon)
        birdsHeaderStack.addArrangedSubview(birdsTitleLabel)
        mainContainer.addSubview(birdListCollectionView)

        // Use adaptive padding based on screen width
        let sidePadding: CGFloat = bounds.width > 500 ? 32 : 20
        let topPadding: CGFloat = bounds.width > 500 ? 32 : 28
        
        let isIPad = bounds.width > 500
        let mapHeightMultiplier: CGFloat = isIPad ? 0.62 : 0.52

        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            mapView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: mainContainer.heightAnchor, multiplier: mapHeightMultiplier),

            mapDimmingOverlay.topAnchor.constraint(equalTo: mapView.topAnchor),
            mapDimmingOverlay.leadingAnchor.constraint(equalTo: mapView.leadingAnchor),
            mapDimmingOverlay.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
            mapDimmingOverlay.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),

            // View in Maps at TOP RIGHT and SMALLER
            viewInMapsButton.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 16),
            viewInMapsButton.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -16),
            viewInMapsButton.heightAnchor.constraint(equalToConstant: 28),

            cityNameLabel.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: topPadding),
            cityNameLabel.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: sidePadding),
            cityNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: viewInMapsButton.leadingAnchor, constant: -12),

            terrainPill.topAnchor.constraint(equalTo: cityNameLabel.bottomAnchor, constant: 10),
            terrainPill.leadingAnchor.constraint(equalTo: cityNameLabel.leadingAnchor),
            terrainPill.heightAnchor.constraint(equalToConstant: 26),

            terrainIcon.leadingAnchor.constraint(equalTo: terrainPill.leadingAnchor, constant: 4),
            terrainIcon.centerYAnchor.constraint(equalTo: terrainPill.centerYAnchor),
            terrainIcon.widthAnchor.constraint(equalToConstant: 18),
            terrainIcon.heightAnchor.constraint(equalToConstant: 18),

            terrainLabel.leadingAnchor.constraint(equalTo: terrainIcon.trailingAnchor, constant: 6),
            terrainLabel.trailingAnchor.constraint(equalTo: terrainPill.trailingAnchor, constant: -10),
            terrainLabel.centerYAnchor.constraint(equalTo: terrainPill.centerYAnchor),

            glassInfoBar.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -16),
            glassInfoBar.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 12),
            glassInfoBar.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -12),
            glassInfoBar.heightAnchor.constraint(equalToConstant: 68),

            infoStack.topAnchor.constraint(equalTo: glassInfoBar.topAnchor),
            infoStack.leadingAnchor.constraint(equalTo: glassInfoBar.leadingAnchor, constant: 4),
            infoStack.trailingAnchor.constraint(equalTo: glassInfoBar.trailingAnchor, constant: -4),
            infoStack.bottomAnchor.constraint(equalTo: glassInfoBar.bottomAnchor),

            birdsHeaderStack.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 20),
            birdsHeaderStack.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 20),

            birdsIcon.widthAnchor.constraint(equalToConstant: 22),
            birdsIcon.heightAnchor.constraint(equalToConstant: 22),

            birdListCollectionView.topAnchor.constraint(equalTo: birdsHeaderStack.bottomAnchor, constant: 16),
            birdListCollectionView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            birdListCollectionView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            birdListCollectionView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -16)
        ])
        
        viewInMapsButton.addTarget(self, action: #selector(didTapViewInMaps), for: .touchUpInside)
    }

    @objc private func didTapViewInMaps() {
        guard let coordinate = currentHotspot?.centerCoordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = currentHotspot?.placeName ?? "Current Location"
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func setupCollectionView() {
        birdListCollectionView.delegate = self
        birdListCollectionView.dataSource = self
        birdListCollectionView.register(SubcardViewCell.self, forCellWithReuseIdentifier: SubcardViewCell.identifier)
    }

    private func createInfoBlock(icon: UIImage?, title: String, subtitle: String, iconColor: UIColor, statusColor: UIColor) -> UIView {
        let v = UIView()
        let iv = UIImageView(image: icon)
        iv.tintColor = iconColor
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        
        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: bounds.width > 500 ? 13 : 11, weight: .bold)
        t.textColor = .label
        t.adjustsFontSizeToFitWidth = true
        t.minimumScaleFactor = 0.8
        t.translatesAutoresizingMaskIntoConstraints = false
        
        let s = UILabel()
        s.text = subtitle
        s.font = .systemFont(ofSize: bounds.width > 500 ? 11 : 9, weight: .medium)
        s.textColor = statusColor
        s.translatesAutoresizingMaskIntoConstraints = false
        
        v.addSubview(iv)
        v.addSubview(t)
        v.addSubview(s)
        
        let iconSize: CGFloat = bounds.width > 500 ? 24 : 18
        
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 4),
            iv.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            iv.widthAnchor.constraint(equalToConstant: iconSize),
            iv.heightAnchor.constraint(equalToConstant: iconSize),
            
            t.topAnchor.constraint(equalTo: v.centerYAnchor, constant: -12),
            t.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 6),
            t.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -2),
            
            s.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 1),
            s.leadingAnchor.constraint(equalTo: t.leadingAnchor),
            s.trailingAnchor.constraint(equalTo: t.trailingAnchor)
        ])
        return v
    }

    // MARK: - Configuration

    func configure(migration: MigrationPrediction, hotspot: HotspotPrediction) {
        self.currentHotspot = hotspot
        cityNameLabel.text = hotspot.placeName
        terrainLabel.text = hotspot.terrainTag
        
        self.birdSpecies = hotspot.birdSpecies
        birdListCollectionView.reloadData()
        
        setupMap(hotspotCenter: hotspot.centerCoordinate, areaOverlay: hotspot.areaOverlay)
        fetchTerrain(for: hotspot.centerCoordinate)
        updateInfoBar(for: hotspot)
    }

    private func updateInfoBar(for hotspot: HotspotPrediction) {
        infoStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let seasonIcon = seasonSymbolAppearance(for: hotspot.seasonTag)
        let dateRange = dateRangeForCurrentWeek()
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        
        // Calculate dynamic activity level
        let activityTitle: String
        let activityColor: UIColor
        if hotspot.speciesCount > 25 {
            activityTitle = "High"
            activityColor = .systemTeal
        } else if hotspot.speciesCount > 12 {
            activityTitle = "Moderate"
            activityColor = .systemYellow
        } else {
            activityTitle = "Steady"
            activityColor = .systemGreen
        }
        
        infoStack.addArrangedSubview(createInfoBlock(icon: UIImage(systemName: seasonIcon.symbolName), title: "\(hotspot.seasonTag) Migration", subtitle: "Active", iconColor: seasonIcon.color, statusColor: .systemGreen))
        infoStack.addArrangedSubview(createInfoBlock(icon: UIImage(systemName: "waveform.path.ecg"), title: "Peak Activity", subtitle: activityTitle, iconColor: .systemTeal, statusColor: activityColor))
        infoStack.addArrangedSubview(createInfoBlock(icon: UIImage(systemName: "calendar"), title: dateRange, subtitle: "Week \(currentWeek)", iconColor: .systemPurple, statusColor: .secondaryLabel))
    }

    private func dateRangeForCurrentWeek() -> String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        var components = DateComponents()
        components.weekOfYear = weekOfYear
        components.yearForWeekOfYear = calendar.component(.yearForWeekOfYear, from: Date())
        components.weekday = 1 // Sunday
        
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else { return "N/A" }
        
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    private func setupMap(hotspotCenter: CLLocationCoordinate2D, areaOverlay: HotspotAreaOverlay) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        let region = MKCoordinateRegion(center: hotspotCenter, latitudinalMeters: 5000, longitudinalMeters: 5000)
        mapView.setRegion(region, animated: false)

        switch areaOverlay {
        case .polygon(let coordinates):
            guard coordinates.count >= 3 else { break }
            var polyCoords = coordinates
            let polygon = MKPolygon(coordinates: &polyCoords, count: polyCoords.count)
            mapView.addOverlay(polygon)
        case .circle(let radiusKm):
            let circle = MKCircle(center: hotspotCenter, radius: radiusKm * 1000)
            mapView.addOverlay(circle)
        }

        let pin = MKPointAnnotation()
        pin.coordinate = hotspotCenter
        mapView.addAnnotation(pin)
    }

    // MARK: - Helpers

    private func fetchTerrain(for coordinate: CLLocationCoordinate2D) {
        let cacheKey = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        if let info = Self.terrainCache[cacheKey] {
            applyTerrain(info, image: Self.terrainImageCache[cacheKey])
            return
        }
        
        geocodingTask = Task {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard let request = MKReverseGeocodingRequest(location: location) else { return }
            do {
                let mapItems = try await request.mapItems
                let info = mapItems.first.map { classifyTerrain(from: $0) } ?? TerrainInfo(name: "Remote Area", symbolName: "mappin.circle", color: .systemGray, defaultImageName: "Terrain_Remote")
                Self.terrainCache[cacheKey] = info
                await MainActor.run { self.applyTerrain(info, image: UIImage(named: info.defaultImageName)) }
            } catch { }
        }
    }

    private func classifyTerrain(from mapItem: MKMapItem) -> TerrainInfo {
        let name = mapItem.name ?? ""
        
        if #available(iOS 13.0, *), let category = mapItem.pointOfInterestCategory {
            switch category {
            case .park, .nationalPark :
                return TerrainInfo(name: "Nature Reserve", symbolName: "leaf.fill", color: .systemGreen, defaultImageName: "Terrain_Wilderness")
            case .beach, .marina:
                return TerrainInfo(name: "Coastal Area", symbolName: "water.waves", color: .systemBlue, defaultImageName: "Terrain_Freshwater")
            case .stadium, .university, .museum:
                return TerrainInfo(name: "Urban Green", symbolName: "building.2.fill", color: .systemGray, defaultImageName: "Terrain_Residential")
            default:
                break
            }
        }
        
        if name.contains("Park") || name.contains("Garden") || name.contains("Lake") || name.contains("Forest") {
            return TerrainInfo(name: name.contains("Lake") ? "Wetlands" : "Parkland", symbolName: "tree.fill", color: .systemGreen, defaultImageName: "Terrain_Land")
        }
        
        if let locality = mapItem.placemark.locality {
            return TerrainInfo(name: "Urban \(locality)", symbolName: "mappin.and.ellipse", color: .systemTeal, defaultImageName: "Terrain_Residential")
        }

        return TerrainInfo(name: "Natural Area", symbolName: "map.fill", color: .systemGreen, defaultImageName: "Terrain_Land")
    }

    private func applyTerrain(_ info: TerrainInfo, image: UIImage?) {
        terrainLabel.text = info.name
        terrainIcon.image = image ?? UIImage(named: info.defaultImageName)
    }

    private func seasonSymbolAppearance(for season: String) -> (symbolName: String, color: UIColor) {
        switch season {
        case "Summer": return ("sun.max.fill", .systemYellow)
        case "Winter": return ("snowflake", .systemBlue)
        case "Autumn": return ("leaf.fill", .systemOrange)
        case "Spring": return ("camera.macro", .systemPink)
        default: return ("circle.fill", .systemGray)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        geocodingTask?.cancel()
        geocodingTask = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let layout = birdListCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let h = birdListCollectionView.bounds.height
            let isIPad = bounds.width > 500
            
            // Refined multipliers to make cards smaller on both platforms
            let heightMultiplier: CGFloat = isIPad ? 0.88 : 0.82
            let widthMultiplier: CGFloat = isIPad ? 1.25 : 1.15
            
            let cardHeight = h * heightMultiplier
            let cardWidth = cardHeight * widthMultiplier
            
            layout.itemSize = CGSize(width: cardWidth, height: cardHeight)
            
            // Centering vertically within the discovery row
            let vInset = (h - cardHeight) / 2
            layout.sectionInset = UIEdgeInsets(top: vInset, left: 20, bottom: vInset, right: 20)
            
            layout.invalidateLayout()
        }
    }
}

extension NewMigrationCollectionViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return birdSpecies.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SubcardViewCell.identifier, for: indexPath) as? SubcardViewCell else { return UICollectionViewCell() }
        cell.configure(with: birdSpecies[indexPath.row])
        return cell
    }
}

extension NewMigrationCollectionViewCell: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let r = MKCircleRenderer(circle: circle)
            r.fillColor = UIColor.abundanceMapColor.withAlphaComponent(0.15)
            r.strokeColor = UIColor.abundanceMapColor.withAlphaComponent(0.8)
            r.lineWidth = 2
            return r
        }
        return MKOverlayRenderer()
    }
}
