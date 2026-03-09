
import UIKit
import CoreLocation
import ImageIO

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var homeCollectionView: UICollectionView!
    
    private let homeManager = HomeManager.shared
    private var homeScreenData: HomeScreenData?
    private let homeTitleProfileImageView = UIImageView()
    private var homeTitleProfileImageConstraints: [NSLayoutConstraint] = []
    private var upcomingBirds: [UpcomingBirdUI] = []
    private var spots: [PopularSpotUI] = []
    private var observations: [CommunityObservation] = []
    private var news: [NewsItem] = []
    private var migrationCards: [DynamicMapCard] = []

    private var cachedUpcomingBirdCardWidth: CGFloat?
    private var cachedSpotsCardWidth: CGFloat?
    private var authStateObserver: NSObjectProtocol?
    private let avatarMaxPixelSize: CGFloat = 512
    private let emptyNewsItem = NewsItem(
        title: "No latest news to load",
        summary: "Please try again later.",
        link: "",
        imageName: "defaultProfile",
        sourceName: nil,
        publishedAt: nil
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        self.title = "Home"
        self.navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        setupHomeTitleProfileImageView()
        applySemanticAppearance()
        setupCollectionView()
        loadHomeData()
        observeUserSessionChanges()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
        homeCollectionView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        attachHomeTitleProfileImageViewIfNeeded()
        refreshHomeData()
        loadUserProfileImage()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        homeTitleProfileImageView.removeFromSuperview()
        NSLayoutConstraint.deactivate(homeTitleProfileImageConstraints)
        homeTitleProfileImageConstraints.removeAll()
    }
    
    @IBAction func profileTapped(_ sender: Any) {
        navigateToProfile()
    }

    private func setupHomeTitleProfileImageView() {

        homeTitleProfileImageView.translatesAutoresizingMaskIntoConstraints = false

        homeTitleProfileImageView.contentMode = .scaleAspectFill
        homeTitleProfileImageView.clipsToBounds = true
        homeTitleProfileImageView.layer.cornerRadius = 18

        homeTitleProfileImageView.isUserInteractionEnabled = true
        homeTitleProfileImageView.accessibilityLabel = "Profile"
        loadUserProfileImage()

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(didTapHomeTitleProfileImage)
        )

        homeTitleProfileImageView.addGestureRecognizer(tapGesture)
    }
    
    private func loadUserProfileImage() {

        guard let user = UserSession.shared.getUser() else {

            homeTitleProfileImageView.image = UIImage(named: "defaultProfile")

            return
        }

        let photo = user.profilePhoto
        if photo.starts(with: "http") {

            loadImage(from: photo)

        } else if photo.starts(with: "file://") || FileManager.default.fileExists(atPath: photo) {

            loadLocalImage(from: photo)

        } else if !photo.isEmpty {

            homeTitleProfileImageView.image = UIImage(named: photo) ?? UIImage(named: "defaultProfile")

        } else {
            homeTitleProfileImageView.image = UIImage(named: "defaultProfile")
        }
    }
    
    private func loadImage(from urlString: String) {

        guard let url = URL(string: urlString) else { return }

        DispatchQueue.global(qos: .userInitiated).async {

            if let data = try? Data(contentsOf: url),
               let image = self.downsampledImage(from: data, maxPixelSize: self.avatarMaxPixelSize) {

                DispatchQueue.main.async {

                    self.homeTitleProfileImageView.image = image
                }
            } else {
                DispatchQueue.main.async {
                    self.homeTitleProfileImageView.image = UIImage(named: "defaultProfile")
                }
            }
        }
    }

    private func loadLocalImage(from pathOrURLString: String) {
        let fileURL: URL?
        if pathOrURLString.starts(with: "file://") {
            fileURL = URL(string: pathOrURLString)
        } else {
            fileURL = URL(fileURLWithPath: pathOrURLString)
        }

        guard let fileURL,
              let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]),
              let image = downsampledImage(from: data, maxPixelSize: avatarMaxPixelSize) else {
            homeTitleProfileImageView.image = UIImage(named: "defaultProfile")
            return
        }

        homeTitleProfileImageView.image = image
    }

    private func observeUserSessionChanges() {
        authStateObserver = NotificationCenter.default.addObserver(
            forName: UserSession.authStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadUserProfileImage()
        }
    }
    private func attachHomeTitleProfileImageViewIfNeeded() {
        guard let navBar = navigationController?.navigationBar else { return }
        guard homeTitleProfileImageView.superview == nil else { return }

        navBar.addSubview(homeTitleProfileImageView)
        homeTitleProfileImageConstraints = [
            homeTitleProfileImageView.widthAnchor.constraint(equalToConstant: 36),
            homeTitleProfileImageView.heightAnchor.constraint(equalToConstant: 36),
            homeTitleProfileImageView.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -16),
            homeTitleProfileImageView.bottomAnchor.constraint(equalTo: navBar.bottomAnchor, constant: -8)
        ]
        NSLayoutConstraint.activate(homeTitleProfileImageConstraints)
    }

    @objc private func didTapHomeTitleProfileImage() {
        navigateToProfile()
    }

    private func navigateToProfile() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        if let profileVC = storyboard.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
            navigationController?.pushViewController(profileVC, animated: true)
        }
    }

    deinit {
        if let authStateObserver {
            NotificationCenter.default.removeObserver(authStateObserver)
        }
    }

    private func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        cachedUpcomingBirdCardWidth = nil
        cachedSpotsCardWidth = nil
        coordinator.animate(alongsideTransition: { _ in
            self.homeCollectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    } 
   
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAllSpots" {
            if let destinationVC = segue.destination as? AllSpotsViewController {
                destinationVC.watchlistData = homeScreenData?.watchlistSpots ?? []
                destinationVC.recommendationsData = homeScreenData?.recommendedSpots ?? []
            }
        }

        if segue.identifier == "ShowAllBirds" {
            if let destinationVC = segue.destination as? AllUpcomingBirdsViewController {
                destinationVC.watchlistData = homeScreenData?.upcomingBirds ?? []
                destinationVC.recommendationsData = homeScreenData?.recommendedBirds ?? []
            }
        }
    }
}

extension HomeViewController {
    private func applySemanticAppearance() {
        view.backgroundColor = .systemBackground
        homeCollectionView?.backgroundColor = .clear
    }

    func setupCollectionView() {
        homeCollectionView.delegate = self
        homeCollectionView.dataSource = self
        homeCollectionView.backgroundColor = .clear
            
        homeCollectionView.register(
            UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil),
            forSupplementaryViewOfKind: "CommunityPageControlFooter",
            withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier
        )
        
        homeCollectionView.register(
            UINib(nibName: "UpcomingBirdsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "UpcomingBirdsCollectionViewCell"
        )
        
        homeCollectionView.register(
            UINib(nibName: "SpotsToVisitCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "SpotsToVisitCollectionViewCell"
        )
        
        homeCollectionView.register(
            UINib(nibName: CommunityObservationsCollectionViewCell.identifier, bundle: nil),
            forCellWithReuseIdentifier: CommunityObservationsCollectionViewCell.identifier
        )
        
        homeCollectionView.register(
            UINib(nibName: NewMigrationCollectionViewCell.identifier, bundle: Bundle(for: NewMigrationCollectionViewCell.self)),
            forCellWithReuseIdentifier: NewMigrationCollectionViewCell.identifier
        )
        
        homeCollectionView.register(
            UINib(nibName: "NewsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "NewsCollectionViewCell"
        )
    
        homeCollectionView.register(
            UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil),
            forSupplementaryViewOfKind: "NewsPageControlFooter",
            withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier
        )
        
        homeCollectionView.register(
            UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderCollectionReusableView.identifier
        )

        homeCollectionView.collectionViewLayout = createLayout()
    }

    private func loadHomeData() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let userLocation = await self.resolveQueryLocation()
            let data = await self.homeManager.getHomeScreenData(userLocation: userLocation)
            self.homeScreenData = data

            if let errorMessage = data.errorMessage {
                self.showErrorAlert(message: errorMessage)
            }
            self.upcomingBirds = data.displayableUpcomingBirds
            self.spots = data.displayableSpots
            self.observations = data.recentObservations
            self.news = data.news
            self.migrationCards = data.migrationCards
            
            self.homeCollectionView.reloadData()
        }
    }

    private func refreshHomeData() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let userLocation = await self.resolveQueryLocation()
            let data = await self.homeManager.getHomeScreenData(userLocation: userLocation)
            
            self.homeScreenData = data
            if let errorMessage = data.errorMessage {
                self.showErrorAlert(message: errorMessage)
            }
            self.upcomingBirds = data.displayableUpcomingBirds
            self.spots = data.displayableSpots
            self.observations = data.recentObservations
            self.news = data.news
            self.migrationCards = data.migrationCards
            self.homeCollectionView.reloadData()
        }
    }

    private func resolveQueryLocation() async -> CLLocationCoordinate2D? {
        if let liveLocation = LocationService.shared.currentLocation {
            await LocationPreferences.shared.setHomeLocation(
                liveLocation,
                name: LocationPreferences.shared.homeLocationName
            )
            return liveLocation
        }

        do {
            let locationData = try await LocationService.shared.getCurrentLocation()
            let coordinate = CLLocationCoordinate2D(
                latitude: locationData.lat,
                longitude: locationData.lon
            )
            await LocationPreferences.shared.setHomeLocation(coordinate, name: locationData.displayName)
            return coordinate
        } catch {
        }

        if let storedHomeLocation = LocationPreferences.shared.homeLocation {
            return storedHomeLocation
        }

        return CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Data Sync Issue", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { [weak self] _ in
            self?.refreshHomeData()
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        self.present(alert, animated: true)
    }

    private func showLocationRequiredAlert() {
        let alert = UIAlertController(
            title: "Location Required",
            message: "To provide personalized birding recommendations, we need your home location. Would you like to use your current location?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Use Current Location", style: .default) { [weak self] _ in
            self?.useCurrentLocationAsHome()
        })

        alert.addAction(UIAlertAction(title: "Go to Profile", style: .default) { [weak self] _ in
            self?.navigateToProfile()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
    }

    private func useCurrentLocationAsHome() {
        Task {
            do {
                let locationData = try await LocationService.shared.getCurrentLocation()
                let coord = CLLocationCoordinate2D(latitude: locationData.lat, longitude: locationData.lon)
                await LocationPreferences.shared.setHomeLocation(coord, name: locationData.displayName)
                self.loadHomeData()
            } catch {
                let errorAlert = UIAlertController(
                    title: "Location Unavailable",
                    message: "Could not determine your current location. Please ensure location services are enabled or set it manually in your profile.",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(errorAlert, animated: true)
            }
        }
    }

	private func navigateToSpotDetails(name: String, lat: Double, lon: Double, radius: Double, predictions: [FinalPredictionResult]) {
			
		var inputData = PredictionInputData()
		inputData.locationName = name
		inputData.latitude = lat
		inputData.longitude = lon
		inputData.areaValue = Int(radius)
		inputData.startDate = Date()
        inputData.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
		
		let storyboard = UIStoryboard(name: "Home", bundle: nil)
		if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
			self.navigationController?.pushViewController(predictMapVC, animated: true)
			
			predictMapVC.loadViewIfNeeded()
			predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
		}
	}

    private func navigateToBirdPrediction(bird: Bird, statusText: String) {
        let (parsedStart, parsedEnd) = homeManager.parseDateRange(statusText)
        let startDate = parsedStart ?? Date()
        let endDate = parsedEnd ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate) ?? startDate

        let input = BirdDateInput(
            species: SpeciesData(id: bird.bird_id.uuidString, name: bird.commonName, imageName: bird.staticImageName),
            startDate: startDate,
            endDate: endDate
        )

        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
            mapVC.predictionInputs = [input]
            self.navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            switch sectionIndex {
            case 0: 
                return self.createMigrationCarouselSection()
            case 1:
                return self.createUpcomingBirdsSection()
            case 2:
                return self.createSpotsToVisitSection()
            case 3:
                return self.createCommunityObservationsSection()
            case 4:
                return self.createNewsSection()
            default:
                return nil
            }
        }
        layout.configuration.contentInsetsReference = .automatic
        return layout
    }
    
    private func createSectionHeaderLayout() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(40)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16)
        return header
    }

    private func createUpcomingBirdsSection() -> NSCollectionLayoutSection {
        let cardWidth: CGFloat
        
        if let cached = cachedUpcomingBirdCardWidth {
            cardWidth = cached
        } else {
            let screenBounds = self.view.window?.windowScene?.screen.bounds ?? self.view.bounds
            let portraitWidth = min(screenBounds.width, screenBounds.height)
            let interGroupSpacing: CGFloat = 16
            let outerPadding: CGFloat = 16 * 2
            let visibleCardProportion: CGFloat = 2.1
            let numberOfSpacings = floor(visibleCardProportion)
            let totalSpacing = (numberOfSpacings * interGroupSpacing) + outerPadding
            let calculatedWidth = (portraitWidth - totalSpacing) / visibleCardProportion
            cardWidth = min(calculatedWidth, 230)
            cachedUpcomingBirdCardWidth = cardWidth
        }
       
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cardWidth),
            heightDimension: .absolute(cardWidth * 1.034)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 16
        section.boundarySupplementaryItems = [createSectionHeaderLayout()]
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        
        return section
    }

    private func createSpotsToVisitSection() -> NSCollectionLayoutSection {
        let cardWidth: CGFloat
        if let cached = cachedSpotsCardWidth {
            cardWidth = cached
        } else {
            let screenBounds = self.view.window?.windowScene?.screen.bounds ?? self.view.bounds
            let portraitWidth = min(screenBounds.width, screenBounds.height)
            
            let interGroupSpacing: CGFloat = 16
            let outerPadding: CGFloat = 16 * 2
            let visibleCardProportion: CGFloat = 2.1
            
            let numberOfSpacings = floor(visibleCardProportion)
            let totalSpacing = (numberOfSpacings * interGroupSpacing) + outerPadding
            
            let calculatedWidth = (portraitWidth - totalSpacing) / visibleCardProportion
            cardWidth = min(calculatedWidth, 230)
            cachedSpotsCardWidth = cardWidth
        }
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cardWidth),
            heightDimension: .absolute(cardWidth * 1.034)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 16
        section.boundarySupplementaryItems = [createSectionHeaderLayout()]
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        
        return section
    }

    private func createCommunityObservationsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(159))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 0
        let pageControlFooterKind = "CommunityPageControlFooter"
        
        let pageControlFooterSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(30)
        )
        
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        let pageControlFooter = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: pageControlFooterSize,
                    elementKind: pageControlFooterKind,
                    alignment: .bottom
                )
        let header = createSectionHeaderLayout()
        section.boundarySupplementaryItems = [header,pageControlFooter]
        return section
    }
    
    private func createNewsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(180))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 0
        let pageControlFooterKind = "NewsPageControlFooter"
        
        let pageControlFooterSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(30)
        )
        
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        let pageControlFooter = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: pageControlFooterSize,
                elementKind: pageControlFooterKind,
                alignment: .bottom
            )
        let header = createSectionHeaderLayout()
        section.boundarySupplementaryItems = [header,pageControlFooter]
        return section
    }
    
    private func createMigrationCarouselSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let screenWidth = self.view.bounds.width
        let absoluteCardWidth = screenWidth - 32
        var calculatedHeight = absoluteCardWidth * (440.0 / 361.0)
        if screenWidth > 400 {
            calculatedHeight = min(calculatedHeight, 650)
        }

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(absoluteCardWidth),
            heightDimension: .absolute(calculatedHeight)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 40
        section.boundarySupplementaryItems = [createSectionHeaderLayout()]
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
        
        return section
    }
}

extension HomeViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: 
            let count = min(migrationCards.count, 1)
            return count
        case 1: return upcomingBirds.count
        case 2: return min(spots.count, 5)
        case 3: return observations.count
        case 4: return max(min(news.count, 5), 1)
        default: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cardType = migrationCards[indexPath.row]
            
            switch cardType {
            case .combined(let migration, let hotspot):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: NewMigrationCollectionViewCell.identifier,
                    for: indexPath
                ) as! NewMigrationCollectionViewCell
                
                cell.configure(migration: migration, hotspot: hotspot)
                return cell
            }
        }
        else if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UpcomingBirdsCollectionViewCell", for: indexPath) as! UpcomingBirdsCollectionViewCell
            let item = upcomingBirds[indexPath.row]
            cell.configure(image: UIImage(named: item.imageName), title: item.title, date: item.date)
            return cell
        }
        else if indexPath.section == 2 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "SpotsToVisitCollectionViewCell",
                for: indexPath
            ) as! SpotsToVisitCollectionViewCell
            
            let item = spots[indexPath.row]
            cell.configure(
                image: UIImage(named: item.imageName),
                title: item.title,
                speciesCount: item.speciesCount,
                latitude: item.latitude,
                longitude: item.longitude
            )
            return cell
        }
        else if indexPath.section == 3 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CommunityObservationsCollectionViewCell.identifier,
                for: indexPath
            ) as! CommunityObservationsCollectionViewCell
            
            let item = observations[indexPath.row]
            cell.configure(
                with: item,
                birdImage: UIImage(named: item.photoURL ?? "default_bird")
            )
            return cell
        }
        else if indexPath.section == 4 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "NewsCollectionViewCell",
                for: indexPath
            ) as! NewsCollectionViewCell
            
            let item = newsItem(at: indexPath.row)
            cell.configure(with: item)
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                         viewForSupplementaryElementOfKind kind: String,
                         at indexPath: IndexPath) -> UICollectionReusableView {
         
         let communityFooterKind = "CommunityPageControlFooter"
         let newsFooterKind = "NewsPageControlFooter"
         
         if kind == communityFooterKind && indexPath.section == 3 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
             let observationCount = observations.count
             footer.configure(numberOfPages: observationCount, currentPage: 0)
             return footer
         }
         else if kind == newsFooterKind && indexPath.section == 4 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
             let count = news.isEmpty ? 0 : min(news.count, 5)
             footer.configure(numberOfPages: count, currentPage: 0)
             return footer
         }
        else if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderCollectionReusableView.identifier,
                for: indexPath
            ) as! SectionHeaderCollectionReusableView

            var action: (() -> Void)? = nil
            if indexPath.section == 0 {
                header.configure(title: "Prediction")
            }
            else if indexPath.section == 1 {
                action = { [weak self] in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "ShowAllBirds", sender: nil)
                }
                header.configure(title: "Upcoming Birds", tapAction: action)
            }
            else if indexPath.section == 2 {
                action = { [weak self] in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "ShowAllSpots", sender: nil)
                }
                header.configure(title: "Spots to Visit", tapAction: action)
            }
            else if indexPath.section == 3 {
                header.configure(title: "Community Observations")
            }
            else if indexPath.section == 4 {
                header.configure(title: "Latest News")
            }
            return header
        }
         return UICollectionReusableView()
     }
}

extension HomeViewController {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.section == 3 {
            let footerKind = "CommunityPageControlFooter"

            if let footer = collectionView.supplementaryView(
                forElementKind: footerKind,
                at: IndexPath(item: 0, section: 3)
            ) as? PageControlReusableViewCollectionReusableView {
                let totalCount = observations.count
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
        else if indexPath.section == 4 {
            let footerKind = "NewsPageControlFooter"
            
            if let footer = collectionView.supplementaryView(
                forElementKind: footerKind,
                at: IndexPath(item: 0, section: 4)
            ) as? PageControlReusableViewCollectionReusableView {
                let totalCount = news.isEmpty ? 0 : min(news.count, 5)
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let cardData = migrationCards[indexPath.row]
            
            switch cardData {
            case .combined(_, let hotspot):
                let lat = hotspot.centerCoordinate.latitude
                let lon = hotspot.centerCoordinate.longitude
                let radius = max(2.0, hotspot.pinRadiusKm)
                let predictions = hotspot.birdSpecies.map { bird in
                    FinalPredictionResult(
                        birdName: bird.birdName,
                        imageName: bird.birdImageName,
                        likelySpot: WatchlistManager.shared.findBird(byName: bird.birdName)?.likelySpot ?? "Sky",
                        matchedInputIndex: 0,
                        matchedLocation: (lat: lat, lon: lon),
                        spottingProbability: bird.sightabilityPercent,
                        weekNumber: bird.weekNumber,
                        residencyStatus: bird.residencyStatus
                    )
                }

                navigateToSpotDetails(
                    name: hotspot.placeName,
                    lat: lat,
                    lon: lon,
                    radius: radius,
                    predictions: predictions
                )
            }
					
        case 1:
            
            let watchlistCount = homeScreenData?.myWatchlistBirds.count ?? 0
            
            let bird: Bird
            let statusText: String
            
            if indexPath.row < watchlistCount {
                guard let result = homeScreenData?.myWatchlistBirds[safe: indexPath.row] else { return }
                bird = result.bird
                statusText = result.statusText
            } else {
                let recommendedIndex = indexPath.row - watchlistCount
                guard let recResult = homeScreenData?.recommendedBirds[safe: recommendedIndex] else { return }
                bird = recResult.bird
                statusText = recResult.dateRange
            }
            
            navigateToBirdPrediction(bird: bird, statusText: statusText)
            
        case 2:
            let item = spots[indexPath.row]
            
            Task {
                let predictions = await homeManager.getLivePredictions(
                    for: item.latitude,
                    lon: item.longitude,
                    radiusKm: item.radius
                )
                
                await MainActor.run {
                    navigateToSpotDetails(
                        name: item.title,
                        lat: item.latitude,
                        lon: item.longitude,
                        radius: item.radius,
                        predictions: predictions
                    )
                }
            }
            
        case 3:
            let observation = observations[indexPath.row]
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            if let detailVC = storyboard.instantiateViewController(withIdentifier: "CommunityObservationViewController") as? CommunityObservationViewController {
                detailVC.observation = observation
                navigationController?.pushViewController(detailVC, animated: true)
            }
            
        case 4:
            guard !news.isEmpty else { return }
            let item = newsItem(at: indexPath.row)
            guard !item.link.isEmpty, let url = URL(string: item.link) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            
        default:
            break
        }
    }

    private func newsItem(at index: Int) -> NewsItem {
        guard !news.isEmpty, index >= 0, index < news.count else {
            return emptyNewsItem
        }
        return news[index]
    }
}
