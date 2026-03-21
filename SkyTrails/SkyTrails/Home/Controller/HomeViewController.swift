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

    private var animatedIndexPaths: Set<IndexPath> = []
    private var cachedUpcomingBirdCardWidth: CGFloat?
    private var cachedSpotsCardWidth: CGFloat?
    private var authStateObserver: NSObjectProtocol?
    private let avatarMaxPixelSize: CGFloat = 512
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let emptyNewsItem = NewsItem(
        title: "The Birds are Resting",
        summary: "No new stories at the moment. Check back soon for the latest updates from the avian world.",
        link: "",
        imageName: "feather", // Using the feather asset which is already in xcassets
        sourceName: "SkyTrails Nature Desk",
        publishedAt: nil
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        self.navigationItem.title = "Home"
        self.tabBarItem.title = "Home"
        self.navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        setupHomeTitleProfileImageView()
        setupLoadingIndicator()
        applySemanticAppearance()
        setupCollectionView()
        loadHomeData()
        observeUserSessionChanges()
    }

    private func setupLoadingIndicator() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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

    // Configures the profile image view in the navigation bar
    private func setupHomeTitleProfileImageView() {
        homeTitleProfileImageView.translatesAutoresizingMaskIntoConstraints = false
        homeTitleProfileImageView.contentMode = .scaleAspectFill
        homeTitleProfileImageView.clipsToBounds = true
        homeTitleProfileImageView.layer.cornerRadius = 18
        homeTitleProfileImageView.isUserInteractionEnabled = true
        homeTitleProfileImageView.accessibilityLabel = "Profile"
        loadUserProfileImage()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapHomeTitleProfileImage))
        homeTitleProfileImageView.addGestureRecognizer(tapGesture)
    }
    
    // Fetches and displays the current user's profile photo
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
                DispatchQueue.main.async { self.homeTitleProfileImageView.image = image }
            } else {
                DispatchQueue.main.async { self.homeTitleProfileImageView.image = UIImage(named: "defaultProfile") }
            }
        }
    }

    private func loadLocalImage(from pathOrURLString: String) {
        let fileURL = pathOrURLString.starts(with: "file://") ? URL(string: pathOrURLString) : URL(fileURLWithPath: pathOrURLString)
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]),
              let image = downsampledImage(from: data, maxPixelSize: avatarMaxPixelSize) else {
            homeTitleProfileImageView.image = UIImage(named: "defaultProfile")
            return
        }
        homeTitleProfileImageView.image = image
    }

    private func observeUserSessionChanges() {
        authStateObserver = NotificationCenter.default.addObserver(forName: UserSession.authStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.loadUserProfileImage()
        }
    }

    // Places the profile image in the large title navigation bar area
    private func attachHomeTitleProfileImageViewIfNeeded() {
        guard let navBar = navigationController?.navigationBar, homeTitleProfileImageView.superview == nil else { return }
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
        if let authStateObserver { NotificationCenter.default.removeObserver(authStateObserver) }
    }

    // Performance optimized image resizing for thumbnails
    private func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        cachedUpcomingBirdCardWidth = nil; cachedSpotsCardWidth = nil
        coordinator.animate(alongsideTransition: { _ in self.homeCollectionView.collectionViewLayout.invalidateLayout() }, completion: nil)
    } 
   
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAllSpots", let dest = segue.destination as? AllSpotsViewController {
            dest.watchlistData = homeScreenData?.watchlistSpots ?? []
            dest.recommendationsData = homeScreenData?.recommendedSpots ?? []
        }
        if segue.identifier == "ShowAllBirds", let dest = segue.destination as? AllUpcomingBirdsViewController {
            dest.watchlistData = homeScreenData?.upcomingBirds ?? []
            dest.recommendationsData = homeScreenData?.recommendedBirds ?? []
        }
    }
}

extension HomeViewController {
    private func applySemanticAppearance() {
        view.backgroundColor = .systemBackground
        homeCollectionView?.backgroundColor = .clear
    }

    func setupCollectionView() {
        homeCollectionView.delegate = self; homeCollectionView.dataSource = self
        
        homeCollectionView.register(UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil), forSupplementaryViewOfKind: "CommunityPageControlFooter", withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier)
        homeCollectionView.register(UINib(nibName: "UpcomingBirdsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "UpcomingBirdsCollectionViewCell")
        homeCollectionView.register(UINib(nibName: "SpotsToVisitCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SpotsToVisitCollectionViewCell")
        homeCollectionView.register(UINib(nibName: CommunityObservationsCollectionViewCell.identifier, bundle: nil), forCellWithReuseIdentifier: CommunityObservationsCollectionViewCell.identifier)
        homeCollectionView.register(UINib(nibName: NewMigrationCollectionViewCell.identifier, bundle: Bundle(for: NewMigrationCollectionViewCell.self)), forCellWithReuseIdentifier: NewMigrationCollectionViewCell.identifier)
        homeCollectionView.register(UINib(nibName: "NewsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NewsCollectionViewCell")
        homeCollectionView.register(UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil), forSupplementaryViewOfKind: "NewsPageControlFooter", withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier)
        homeCollectionView.register(UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier)

        homeCollectionView.collectionViewLayout = createLayout()
    }

    // Fetches comprehensive home screen data asynchronously
    private func loadHomeData() {
        loadingIndicator.startAnimating()
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let data = await self.homeManager.getHomeScreenData(userLocation: await self.resolveQueryLocation())
            self.homeScreenData = data
            if let msg = data.errorMessage { self.showErrorAlert(message: msg) }
            self.upcomingBirds = data.displayableUpcomingBirds; self.spots = data.displayableSpots
            self.observations = data.recentObservations; self.news = data.news
            self.migrationCards = data.migrationCards; self.loadingIndicator.stopAnimating()
            self.animatedIndexPaths.removeAll()
            UIView.transition(with: self.homeCollectionView, duration: 0.4, options: .transitionCrossDissolve, animations: { self.homeCollectionView.reloadData() })
        }
    }

    private func refreshHomeData() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let data = await self.homeManager.getHomeScreenData(userLocation: await self.resolveQueryLocation())
            self.homeScreenData = data
            if let msg = data.errorMessage { self.showErrorAlert(message: msg) }
            self.upcomingBirds = data.displayableUpcomingBirds; self.spots = data.displayableSpots
            self.observations = data.recentObservations; self.news = data.news
            self.migrationCards = data.migrationCards; self.animatedIndexPaths.removeAll()
            UIView.transition(with: self.homeCollectionView, duration: 0.3, options: .transitionCrossDissolve, animations: { self.homeCollectionView.reloadData() })
        }
    }

    // Resolves location using live GPS or fallbacks to preferences
    private func resolveQueryLocation() async -> CLLocationCoordinate2D? {
        if let live = LocationService.shared.currentLocation {
            await LocationPreferences.shared.setHomeLocation(live, name: LocationPreferences.shared.homeLocationName)
            return live
        }
        do {
            let data = try await LocationService.shared.getCurrentLocation()
            let coord = CLLocationCoordinate2D(latitude: data.lat, longitude: data.lon)
            await LocationPreferences.shared.setHomeLocation(coord, name: data.displayName)
            return coord
        } catch { }
        return LocationPreferences.shared.homeLocation ?? CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Sync Issue", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in self?.refreshHomeData() })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

	private func navigateToSpotDetails(name: String, lat: Double, lon: Double, radius: Double, predictions: [FinalPredictionResult]) {
		var inputData = PredictionInputData(); inputData.locationName = name; inputData.latitude = lat; inputData.longitude = lon; inputData.areaValue = Int(radius); inputData.startDate = Date(); inputData.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
		let storyboard = UIStoryboard(name: "Home", bundle: nil)
		if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
			navigationController?.pushViewController(predictMapVC, animated: true)
			predictMapVC.loadViewIfNeeded(); predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
		}
	}

    private func navigateToBirdPrediction(bird: Bird, statusText: String) {
        let (start, end) = homeManager.parseDateRange(statusText)
        let sDate = start ?? Date(); let eDate = end ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: sDate) ?? sDate
        let input = BirdDateInput(species: SpeciesData(id: bird.bird_id.uuidString, name: bird.commonName, imageName: bird.staticImageName), startDate: sDate, endDate: eDate)
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
            mapVC.predictionInputs = [input]; navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    // Defines the complex compositional layout for the home screen sections
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch sectionIndex {
            case 0: return self.createMigrationCarouselSection()
            case 1: return self.createUpcomingBirdsSection()
            case 2: return self.createSpotsToVisitSection()
            case 3: return self.createCommunityObservationsSection()
            case 4: return self.createNewsSection()
            default: return nil
            }
        }
        layout.configuration.contentInsetsReference = .automatic; return layout
    }
    
    private func createSectionHeaderLayout() -> NSCollectionLayoutBoundarySupplementaryItem {
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(40)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16); return header
    }

    private func createUpcomingBirdsSection() -> NSCollectionLayoutSection {
        let cardWidth: CGFloat
        if let cached = cachedUpcomingBirdCardWidth { cardWidth = cached } else {
            let portraitWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
            cardWidth = min((portraitWidth - 64) / 2.1, 230); cachedUpcomingBirdCardWidth = cardWidth
        }
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .absolute(cardWidth * 1.034)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous; section.interGroupSpacing = 16; section.boundarySupplementaryItems = [createSectionHeaderLayout()]; section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16); return section
    }

    private func createSpotsToVisitSection() -> NSCollectionLayoutSection {
        let cardWidth: CGFloat
        if let cached = cachedSpotsCardWidth { cardWidth = cached } else {
            let portraitWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
            cardWidth = min((portraitWidth - 64) / 2.1, 230); cachedSpotsCardWidth = cardWidth
        }
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .absolute(cardWidth * 1.034)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous; section.interGroupSpacing = 16; section.boundarySupplementaryItems = [createSectionHeaderLayout()]; section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16); return section
    }

    private func createCommunityObservationsSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let height: CGFloat = isPad ? 280 : 159
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(height)), subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered; section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        let pageControl = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(30)), elementKind: "CommunityPageControlFooter", alignment: .bottom)
        section.boundarySupplementaryItems = [createSectionHeaderLayout(), pageControl]; return section
    }
    
    private func createNewsSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(180)), subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered; section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        let pageControl = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(30)), elementKind: "NewsPageControlFooter", alignment: .bottom)
        section.boundarySupplementaryItems = [createSectionHeaderLayout(), pageControl]; return section
    }
    
    private func createMigrationCarouselSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let absoluteWidth = view.bounds.width - 32
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(absoluteWidth), heightDimension: .absolute(min(absoluteWidth * (440.0 / 361.0), 650))), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered; section.interGroupSpacing = 40; section.boundarySupplementaryItems = [createSectionHeaderLayout()]; section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16); return section
    }
}

extension HomeViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { return 5 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return min(migrationCards.count, 1)
        case 1: return upcomingBirds.count; case 2: return min(spots.count, 5)
        case 3: return observations.count; case 4: return max(min(news.count, 5), 1)
        default: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            if case .combined(let migration, let hotspot) = migrationCards[indexPath.row] {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NewMigrationCollectionViewCell.identifier, for: indexPath) as! NewMigrationCollectionViewCell
                cell.configure(migration: migration, hotspot: hotspot); return cell
            }
        } else if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UpcomingBirdsCollectionViewCell", for: indexPath) as! UpcomingBirdsCollectionViewCell
            let item = upcomingBirds[indexPath.row]; cell.configure(image: UIImage(named: item.imageName), title: item.title, date: item.date); return cell
        } else if indexPath.section == 2 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotsToVisitCollectionViewCell", for: indexPath) as! SpotsToVisitCollectionViewCell
            let item = spots[indexPath.row]; cell.configure(image: UIImage(named: item.imageName), title: item.title, speciesCount: item.speciesCount, latitude: item.latitude, longitude: item.longitude); return cell
        } else if indexPath.section == 3 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CommunityObservationsCollectionViewCell.identifier, for: indexPath) as! CommunityObservationsCollectionViewCell
            let item = observations[indexPath.row]; cell.configure(with: item, birdImage: UIImage(named: item.photoURL ?? "default_bird")); return cell
        } else if indexPath.section == 4 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NewsCollectionViewCell", for: indexPath) as! NewsCollectionViewCell
            cell.configure(with: newsItem(at: indexPath.row)); return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
         if kind == "CommunityPageControlFooter" || kind == "NewsPageControlFooter" {
             let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier, for: indexPath) as! PageControlReusableViewCollectionReusableView
             let count = kind == "CommunityPageControlFooter" ? observations.count : (news.isEmpty ? 0 : min(news.count, 5))
             footer.configure(numberOfPages: count, currentPage: 0); return footer
         } else if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier, for: indexPath) as! SectionHeaderCollectionReusableView
            if indexPath.section == 0 { header.configure(title: migrationCards.isEmpty ? "No Active Migrations" : "Migration Forecast") }
            else if indexPath.section == 1 { header.configure(title: upcomingBirds.isEmpty ? "No Recent Sightings" : "Birding Highlights", tapAction: { [weak self] in self?.performSegue(withIdentifier: "ShowAllBirds", sender: nil) }) }
            else if indexPath.section == 2 { header.configure(title: spots.isEmpty ? "No Nearby Hotspots" : "Top Birding Spots", tapAction: { [weak self] in self?.performSegue(withIdentifier: "ShowAllSpots", sender: nil) }) }
            else if indexPath.section == 3 { header.configure(title: observations.isEmpty ? "No Recent Community Posts" : "Community Sightings") }
            else if indexPath.section == 4 { header.configure(title: news.isEmpty ? "No Latest News" : "Birders' Gossip") }
            return header
        }
         return UICollectionReusableView()
     }
}

extension HomeViewController {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !animatedIndexPaths.contains(indexPath) {
            cell.alpha = 0; cell.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.5, delay: 0.02 * Double(indexPath.item), usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction], animations: { cell.alpha = 1; cell.transform = .identity }, completion: { _ in self.animatedIndexPaths.insert(indexPath) })
        }
        if indexPath.section == 3, let footer = collectionView.supplementaryView(forElementKind: "CommunityPageControlFooter", at: IndexPath(item: 0, section: 3)) as? PageControlReusableViewCollectionReusableView {
            footer.configure(numberOfPages: observations.count, currentPage: indexPath.row)
        } else if indexPath.section == 4, let footer = collectionView.supplementaryView(forElementKind: "NewsPageControlFooter", at: IndexPath(item: 0, section: 4)) as? PageControlReusableViewCollectionReusableView {
            footer.configure(numberOfPages: news.isEmpty ? 0 : min(news.count, 5), currentPage: indexPath.row)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            if case .combined(_, let hotspot) = migrationCards[indexPath.row] {
                let radius = max(2.0, hotspot.pinRadiusKm); let preds = hotspot.birdSpecies.map { FinalPredictionResult(birdName: $0.birdName, imageName: $0.birdImageName, likelySpot: WatchlistManager.shared.findBird(byName: $0.birdName)?.likelySpot ?? "Sky", matchedInputIndex: 0, matchedLocation: (lat: hotspot.centerCoordinate.latitude, lon: hotspot.centerCoordinate.longitude), spottingProbability: $0.sightabilityPercent, weekNumber: $0.weekNumber, residencyStatus: $0.residencyStatus) }
                navigateToSpotDetails(name: hotspot.placeName, lat: hotspot.centerCoordinate.latitude, lon: hotspot.centerCoordinate.longitude, radius: radius, predictions: preds)
            }
        case 1:
            let wCount = homeScreenData?.myWatchlistBirds.count ?? 0
            if indexPath.row < wCount { if let res = homeScreenData?.myWatchlistBirds[safe: indexPath.row] { navigateToBirdPrediction(bird: res.bird, statusText: res.statusText) } }
            else { if let rec = homeScreenData?.recommendedBirds[safe: indexPath.row - wCount] { navigateToBirdPrediction(bird: rec.bird, statusText: rec.dateRange) } }
        case 2:
            let item = spots[indexPath.row]; Task { let preds = await homeManager.getLivePredictions(for: item.latitude, lon: item.longitude, radiusKm: item.radius); await MainActor.run { navigateToSpotDetails(name: item.title, lat: item.latitude, lon: item.longitude, radius: item.radius, predictions: preds) } }
        case 3:
            let detailVC = UIStoryboard(name: "Home", bundle: nil).instantiateViewController(withIdentifier: "CommunityObservationViewController") as! CommunityObservationViewController
            detailVC.observation = observations[indexPath.row]; navigationController?.pushViewController(detailVC, animated: true)
        case 4:
            let item = newsItem(at: indexPath.row); if let url = URL(string: item.link), UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
        default: break
        }
    }

    private func newsItem(at index: Int) -> NewsItem {
        return (!news.isEmpty && index >= 0 && index < news.count) ? news[index] : emptyNewsItem
    }
}
