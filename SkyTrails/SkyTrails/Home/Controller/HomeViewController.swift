import UIKit
import CoreLocation
import ImageIO

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var homeCollectionView: UICollectionView!
    
    private let homeManager = HomeManager.shared
    private var homeScreenData: HomeScreenData?
    private let profileLocationHeaderView = ProfileLocationHeaderView()
    private var upcomingBirds: [UpcomingBirdUI] = []
    private var spots: [PopularSpotUI] = []
    private var news: [NewsItem] = []
    private var migrationCards: [DynamicMapCard] = []
    private var mlPredictionInputsByBirdName: [String: BirdDateInput] = [:]
    private var currentNewsPage = 0

    private var animatedIndexPaths: Set<IndexPath> = []
    private var cachedUpcomingBirdCardWidth: CGFloat?
    private var cachedSpotsCardWidth: CGFloat?
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var isDataLoading = false
    private var hasLoadedOnce = false


    private let emptyNewsItem = NewsItem(
        title: "The Birds are Resting",
        summary: "No new stories at the moment. Check back soon for the latest updates from the avian world.",
        link: "",
        imageName: "feather", // Using the feather asset which is already in xcassets
        sourceName: "SkyTrails Nature Desk",
        publishedAt: nil
    )

    private enum HomeMLDataError: Error {
        case fileNotFound
    }

    private struct HomeMLDataSnapshot: Decodable {
        let birdId: String
        let commonName: String
        let startWeek: Int
        let endWeek: Int
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        self.navigationItem.title = "Home"
        self.tabBarItem.title = "Home"
        self.navigationItem.largeTitleDisplayMode = .automatic
        navigationController?.navigationBar.prefersLargeTitles = true
        view.sendSubviewToBack(homeCollectionView)
        homeCollectionView.contentInsetAdjustmentBehavior = .always
        setupProfileLocationHeaderView()
        setupLoadingIndicator()
        applySemanticAppearance()
        setupCollectionView()
        setupLocationChangeObserver()
        setupAuthStateObserver()
        
        // Reset to GPS mode on launch if authorized, fulfilling the requirement 
        // to start with current location if permission is available.
        if LocationService.shared.isAuthorized {
            LocationPreferences.shared.isManualOverride = false
        }
        
        // Removed loadHomeData() from here to prevent double-loading with viewWillAppear
    }

    private func setupAuthStateObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChange),
            name: UserSession.authStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleAuthStateChange() {
        print("[DEBUG] HomeVC - Auth state changed. Refreshing data and checking tour...")
        refreshHomeData()
        
        // After auth change (like signup), data refresh is triggered.
        // Once that refresh completes (in loadHomeData/fetchHomeData), 
        // the checkAndStartTourIfNeeded() already gets called.
        // However, if the session was restored or changed without a full refresh needed,
        // we call it here as well after a short delay for safety.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAndStartTourIfNeeded()
        }
    }

    private func setupLocationChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationChange),
            name: LocationPreferences.locationDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationChange),
            name: LocationService.authorizationDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleLocationChange(notification: Notification) {
        if notification.name == LocationService.authorizationDidChangeNotification {
            if LocationService.shared.isAuthorized {
                print("[DEBUG] HomeVC - Authorization granted. Switching to GPS mode.")
                LocationPreferences.shared.isManualOverride = false
            }
        }
        
        print("[DEBUG] HomeVC - Location/Auth changed. Refreshing...")
        refreshHomeData()
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
        configureNavigationBar()
        
        if !hasLoadedOnce {
            loadHomeData()
            hasLoadedOnce = true
        } else if homeScreenData == nil {
            loadHomeData()
        }
        
        profileLocationHeaderView.refreshLocation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Only track appearance if tour is already active (helps with auto-navigation awareness)
        if AppTourManager.shared.isTourActive {
            AppTourManager.shared.trackViewControllerAppeared(self)
        } else if homeScreenData != nil && !isDataLoading {
            // Data is already here (e.g. returning from signup), try starting the tour
            checkAndStartTourIfNeeded()
        }
    }
    
    /// Evaluates onboarding tour eligibility and starts it only after the app has "Fully Loaded" (data is ready)
    private func checkAndStartTourIfNeeded() {
        guard !AppTourManager.shared.isTourActive else { return }
        
        // Delay slightly to ensure any modal dismissals or view transitions are settled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            guard !AppTourManager.shared.isTourActive else { return }
            
            let hasCompletedGuestTour = UserDefaults.standard.bool(forKey: "hasCompletedGuestTour")
            let isAuthenticated = UserSession.shared.isAuthenticatedWithSupabase()
            
            if !isAuthenticated && !hasCompletedGuestTour {
                // Guest Tour: Data is ready, view is settled
                if self.isViewLoaded && self.view.window != nil {
                    AppTourManager.shared.startGuestTour(from: self)
                }
            } else {
                // Member/Signup Tour
                let isNewSignUp = UserDefaults.standard.bool(forKey: "isNewSignUp")
                let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                
                if isAuthenticated && isNewSignUp && !hasCompletedOnboarding {
                    if self.isViewLoaded && self.view.window != nil {
                        AppTourManager.shared.startTour(from: self)
                    }
                }
            }
        }
    }
    
    @IBAction func profileTapped(_ sender: Any) {
        navigateToProfile()
    }

    // Configures the profile location header view in the navigation bar
    private func setupProfileLocationHeaderView() {
        profileLocationHeaderView.onTap = { [weak self] in
            self?.navigateToProfile()
        }
        let heightConstraint = profileLocationHeaderView.heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.priority = .init(999)
        heightConstraint.isActive = true
    }
    
    private func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: profileLocationHeaderView)
    }

    private func navigateToProfile() {
        if !UserSession.shared.isAuthenticatedWithSupabase() {
            if let rootTabBar = tabBarController as? RootTabBarController {
                rootTabBar.presentAuthenticationFlow()
            } else {
                let storyboard = UIStoryboard(name: "Onboard", bundle: nil)
                if let startVC = storyboard.instantiateViewController(withIdentifier: "StartViewController") as? StartViewController {
                    startVC.modalPresentationStyle = .pageSheet
                    present(startVC, animated: true, completion: nil)
                }
            }
            return
        }
        
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        if let profileVC = storyboard.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
            navigationController?.pushViewController(profileVC, animated: true)
        }
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
            dest.userCoordinate = LocationPreferences.shared.homeLocation
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
        
        homeCollectionView.register(UINib(nibName: "UpcomingBirdsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "UpcomingBirdsCollectionViewCell")
        homeCollectionView.register(UINib(nibName: "SpotsToVisitCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SpotsToVisitCollectionViewCell")
        homeCollectionView.register(UINib(nibName: "PredictionButtonCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PredictionButtonCollectionViewCell.identifier)
        homeCollectionView.register(UINib(nibName: NewMigrationCollectionViewCell.identifier, bundle: Bundle(for: NewMigrationCollectionViewCell.self)), forCellWithReuseIdentifier: NewMigrationCollectionViewCell.identifier)
        homeCollectionView.register(UINib(nibName: "NewsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NewsCollectionViewCell")
        homeCollectionView.register(UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil), forSupplementaryViewOfKind: "NewsPageControlFooter", withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier)
        homeCollectionView.register(UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier)

        homeCollectionView.collectionViewLayout = createLayout()
    }

    // Fetches comprehensive home screen data asynchronously
    private func loadHomeData() {
        fetchHomeData(isInitialLoad: true, forceRefresh: false)
    }

    private func refreshHomeData() {
        fetchHomeData(isInitialLoad: false, forceRefresh: true)
    }

    private func fetchHomeData(isInitialLoad: Bool, forceRefresh: Bool) {
        guard !isDataLoading else { return }
        isDataLoading = true
        
        if isInitialLoad {
            loadingIndicator.startAnimating()
        }

        Task { @MainActor [weak self] in
            defer { 
                self?.isDataLoading = false
                self?.loadingIndicator.stopAnimating()
            }
            guard let self = self else { return }
            
            let data = await self.homeManager.getHomeScreenData(
                userLocation: await self.resolveQueryLocation(),
                forceRefresh: forceRefresh
            )
            self.homeScreenData = data
            if let msg = data.errorMessage { self.showErrorAlert(message: msg) }
            
            self.upcomingBirds = data.displayableUpcomingBirds
            self.spots = data.displayableSpots
            self.news = data.news
            self.currentNewsPage = self.clampedNewsPage(self.currentNewsPage)
            self.migrationCards = data.migrationCards
            self.animatedIndexPaths.removeAll()

            // Prefetch images to improve perceived performance
            var imageKeys = Set<String>()
            data.upcomingBirds.forEach { imageKeys.insert($0.imageName) }
            data.displayableSpots.forEach { imageKeys.insert($0.imageName) }
            data.news.forEach { imageKeys.insert($0.imageName) }
            data.migrationCards.forEach { card in
                imageKeys.insert(card.migration.birdImageName)
                imageKeys.insert(card.hotspot.placeImageName)
                card.hotspot.birdSpecies.forEach { imageKeys.insert($0.birdImageName) }
            }

            self.homeCollectionView.reloadData()

            let keysArray = Array(imageKeys).filter { !$0.isEmpty }
            if !keysArray.isEmpty {
                Task.detached(priority: .background) {
                    await ImageService.shared.prefetch(keys: keysArray)
                }
            }
            
            // Start the tour now that data is loaded and UI is ready
            self.checkAndStartTourIfNeeded()
        }
    }

    // Resolves location using live GPS or fallbacks to preferences

    private func resolveQueryLocation() async -> CLLocationCoordinate2D? {
        let isManualOverride = LocationPreferences.shared.isManualOverride
        
        // 1. If user explicitly set a location IN THIS SESSION (or explicitly locked it), use it.
        // This ensures the Manual Picker works immediately after selection.
        if isManualOverride, let saved = LocationPreferences.shared.homeLocation {
            return saved
        }

        // 2. Prime authorization (this triggers the system prompt if needed)
        await LocationService.shared.primeAuthorizationIfNeeded()
        
        // 3. If GPS is authorized, prioritize live current location
        if LocationService.shared.isAuthorized {
            // Check for immediate cached location
            if let live = LocationService.shared.currentLocation {
                await LocationPreferences.shared.setHomeLocation(live, isManual: false)
                return live
            }
            
            // Try to fetch fresh fix
            do {
                let data = try await LocationService.shared.getCurrentLocation()
                let coord = CLLocationCoordinate2D(latitude: data.lat, longitude: data.lon)
                await LocationPreferences.shared.setHomeLocation(coord, name: data.displayName, isManual: false)
                return coord
            } catch {
                print("[DEBUG] GPS Fetch failed: \(error.localizedDescription)")
            }
        }
        
        // 4. Fallback to any saved location or last known spot (Manual or previous GPS)
        if let saved = LocationPreferences.shared.homeLocation {
            return saved
        }
        
        // 5. Absolute fallback (Pune, India)
        return CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    }


    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Sync Issue", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in self?.refreshHomeData() })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

	@discardableResult
	private func navigateToSpotDetails(name: String, lat: Double, lon: Double, radius: Double, predictions: [FinalPredictionResult], startDate: Date? = nil, endDate: Date? = nil) -> PredictMapViewController? {
		var inputData = PredictionInputData(); inputData.locationName = name; inputData.latitude = lat; inputData.longitude = lon; inputData.areaValue = Int(radius); inputData.startDate = startDate ?? Date(); inputData.endDate = endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())
		let storyboard = UIStoryboard(name: "Home", bundle: nil)
		if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
			navigationController?.pushViewController(predictMapVC, animated: true)
			predictMapVC.loadViewIfNeeded(); predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
            return predictMapVC
		}
        return nil
	}

    private func navigateToBirdPrediction(bird: Bird, statusText: String) {
        let (start, end) = homeManager.parseDateRange(statusText)
        let sDate = start ?? Date(); let eDate = end ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: sDate) ?? sDate
        let input = BirdDateInput(
            species: SpeciesData(
                id: bird.bird_id.uuidString, 
                name: bird.commonName, 
                imageName: bird.imageUrl ?? bird.staticImageName,
                ebirdSpeciesCode: bird.ebird_species_code
            ), 
            startDate: sDate, 
            endDate: eDate
        )
        navigateToBirdPrediction(input: input)
    }

    private func navigateToBirdPrediction(input: BirdDateInput) {
        let storyboard = UIStoryboard(name: "Birdspred", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? BirdspredViewController {
            mapVC.predictionInputs = [input]
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }

    private func applyMLDataOverride() {
        guard let snapshots = try? loadMLDataSnapshots(), !snapshots.isEmpty else {
            mlPredictionInputsByBirdName = [:]
            upcomingBirds = homeScreenData?.displayableUpcomingBirds ?? []
            return
        }

        let fallbackUpcomingBirds = homeScreenData?.displayableUpcomingBirds ?? []
        var inputsByBirdName: [String: BirdDateInput] = [:]

        upcomingBirds = snapshots.map { snapshot in
            let fallbackImageName = snapshot.commonName
            let bird = WatchlistManager.shared.findBird(byName: snapshot.commonName)
            let imageName = bird?.imageUrl ?? bird?.staticImageName
                ?? fallbackUpcomingBirds.first(where: { $0.title.caseInsensitiveCompare(snapshot.commonName) == .orderedSame })?.imageName
                ?? fallbackImageName
            print("[DEBUG] applyMLDataOverride - bird=\(snapshot.commonName) imageName=\(imageName) bird.imageUrl=\(bird?.imageUrl ?? "nil") bird.staticImageName=\(bird?.staticImageName ?? "nil")")
            let startDate = weekDate(snapshot.startWeek) ?? Date()
            let endDate = weekDate(snapshot.endWeek) ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate) ?? startDate

            inputsByBirdName[snapshot.commonName.lowercased()] = BirdDateInput(
                species: SpeciesData(
                    id: snapshot.birdId, 
                    name: snapshot.commonName, 
                    imageName: imageName,
                    ebirdSpeciesCode: bird?.ebird_species_code
                ),
                startDate: startDate,
                endDate: endDate
            )

            return UpcomingBirdUI(
                imageName: imageName,
                title: snapshot.commonName,
                date: formatWeekRange(startWeek: snapshot.startWeek, endWeek: snapshot.endWeek),
                ebirdSpeciesCode: bird?.ebird_species_code
            )
        }

        mlPredictionInputsByBirdName = inputsByBirdName
    }

    private func loadMLDataSnapshots() throws -> [HomeMLDataSnapshot] {
        guard let url = Bundle.main.url(forResource: "MLdata", withExtension: "json") else {
            throw HomeMLDataError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([HomeMLDataSnapshot].self, from: data)
    }

    private func weekDate(_ week: Int) -> Date? {
        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = Calendar.current.component(.yearForWeekOfYear, from: Date())
        components.weekday = 2
        return Calendar.current.date(from: components)
    }

    private func formatWeekRange(startWeek: Int, endWeek: Int) -> String {
        return "Week \(startWeek) - Week \(endWeek)"
    }

    private func navigateToNewsArticle(_ item: NewsItem) {
        guard let url = URL(string: item.link) else {
            showErrorAlert(message: "This article link is unavailable right now.")
            return
        }

        let browserViewController = InAppBrowserViewController(url: url, title: item.sourceName ?? item.title)
        navigationController?.pushViewController(browserViewController, animated: true)
    }
    
    // Defines the complex compositional layout for the home screen sections
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch sectionIndex {
            case 0: return self.createMigrationCarouselSection()
            case 1: return self.createUpcomingBirdsSection()
            case 2: return self.createSpotsToVisitSection()
            case 3: return self.createNewsSection()
            default: return nil
            }
        }
        layout.configuration.contentInsetsReference = .automatic; return layout
    }
    
    private func createSectionHeaderLayout() -> NSCollectionLayoutBoundarySupplementaryItem {
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(36)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16); return header
    }

    private func createUpcomingBirdsSection() -> NSCollectionLayoutSection {
        let cardWidth: CGFloat
        if let cached = cachedUpcomingBirdCardWidth { cardWidth = cached } else {
            let collectionBounds = homeCollectionView?.bounds ?? .zero
            let referenceWidth = max(collectionBounds.width, view.bounds.width)
            let referenceHeight = max(collectionBounds.height, view.bounds.height)
            let portraitWidth = min(referenceWidth, referenceHeight)
            cardWidth = min((portraitWidth - 64) / 2.1, 230); cachedUpcomingBirdCardWidth = cardWidth
        }
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .absolute(cardWidth * 1.034)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous; section.interGroupSpacing = 16
        
        section.boundarySupplementaryItems = [createSectionHeaderLayout()]
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        
        return section
    }

    private func createSpotsToVisitSection() -> NSCollectionLayoutSection {
        let cardWidth: CGFloat
        if let cached = cachedSpotsCardWidth { cardWidth = cached } else {
            let collectionBounds = homeCollectionView?.bounds ?? .zero
            let referenceWidth = max(collectionBounds.width, view.bounds.width)
            let referenceHeight = max(collectionBounds.height, view.bounds.height)
            let portraitWidth = min(referenceWidth, referenceHeight)
            cardWidth = min((portraitWidth - 64) / 2.1, 230); cachedSpotsCardWidth = cardWidth
        }
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .absolute(cardWidth * 1.034)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous; section.interGroupSpacing = 16
        
        section.boundarySupplementaryItems = [createSectionHeaderLayout()]
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        
        return section
    }

    private func createNewsSection() -> NSCollectionLayoutSection {
        // Taller cards for vertical blog style
        let newsCardHeight: CGFloat = traitCollection.userInterfaceIdiom == .phone ? 310 : 280
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        
        // Use a 0.82 width for a nice "peek" of the next card
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.82), heightDimension: .absolute(newsCardHeight)), subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 10, bottom: 24, trailing: 10)
        
        section.visibleItemsInvalidationHandler = { [weak self] visibleItems, contentOffset, environment in
            guard let self else { return }
            let containerWidth = environment.container.contentSize.width
            let centerX = contentOffset.x + (containerWidth / 2)
            
            let currentPage = visibleItems
                .filter { $0.representedElementCategory == .cell }
                .min { abs($0.frame.midX - centerX) < abs($1.frame.midX - centerX) }?
                .indexPath.item ?? 0

            Task { @MainActor [weak self] in
                self?.updateNewsPage(to: currentPage)
            }
        }
        
        let pageControl = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(30)), elementKind: "NewsPageControlFooter", alignment: .bottom)
        section.boundarySupplementaryItems = [createSectionHeaderLayout(), pageControl]
        return section
    }
    
    private func createMigrationCarouselSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let absoluteWidth = view.bounds.width - 32
        // Increased card height for better fit on all devices
        let cardHeight: CGFloat = traitCollection.userInterfaceIdiom == .phone ? 480 : 540
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(absoluteWidth), heightDimension: .absolute(cardHeight)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered; section.interGroupSpacing = 40; section.boundarySupplementaryItems = [createSectionHeaderLayout()]; section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16); return section
    }
}

extension HomeViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { return 4 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return min(migrationCards.count, 1)
        case 1: return upcomingBirds.count + 1
        case 2: return min(spots.count, 5) + 1
        case 3: return max(min(news.count, 8), 1)
        default: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let card = migrationCards[indexPath.row]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NewMigrationCollectionViewCell.identifier, for: indexPath) as! NewMigrationCollectionViewCell
            cell.configure(migration: card.migration, hotspot: card.hotspot); return cell
        } else if indexPath.section == 1 {
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PredictionButtonCollectionViewCell.identifier, for: indexPath) as! PredictionButtonCollectionViewCell
                cell.configure(with: UIImage(named: "custom.curvepath.magnifying"), title: "Predict Migrations")
                cell.contentView.alpha = 1.0
                cell.isHidden = false
                return cell
            }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UpcomingBirdsCollectionViewCell", for: indexPath) as! UpcomingBirdsCollectionViewCell
            let item = upcomingBirds[indexPath.row - 1]
            cell.configure(image: nil, imageName: item.imageName, title: item.title, date: item.date)
            return cell


        } else if indexPath.section == 2 {
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PredictionButtonCollectionViewCell.identifier, for: indexPath) as! PredictionButtonCollectionViewCell
                cell.configure(with: UIImage(named: "upcomingspots"), title: "Find Your Spots")
                cell.contentView.alpha = 1.0
                cell.isHidden = false
                return cell
            }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotsToVisitCollectionViewCell", for: indexPath) as! SpotsToVisitCollectionViewCell
            let item = spots[indexPath.row - 1]
            cell.configure(image: nil, imageName: item.imageName, title: item.title, speciesCount: item.speciesCount, latitude: item.latitude, longitude: item.longitude)
            return cell


        } else if indexPath.section == 3 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NewsCollectionViewCell", for: indexPath) as! NewsCollectionViewCell
            cell.configure(with: newsItem(at: indexPath.row)); return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
         if kind == "NewsPageControlFooter" {
             let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier, for: indexPath) as! PageControlReusableViewCollectionReusableView
             let count = news.isEmpty ? 0 : min(news.count, 8)
             footer.configure(numberOfPages: count, currentPage: clampedNewsPage(currentNewsPage)); return footer
         } else if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier, for: indexPath) as! SectionHeaderCollectionReusableView
            if indexPath.section == 0 { header.configure(title: "Your Area") }
            else if indexPath.section == 1 { header.configure(title: "This Week's Species", tapAction: { [weak self] in self?.performSegue(withIdentifier: "ShowAllBirds", sender: nil) }) }
            else if indexPath.section == 2 { header.configure(title: "Top Birding Spots", tapAction: { [weak self] in self?.performSegue(withIdentifier: "ShowAllSpots", sender: nil) }) }
            else if indexPath.section == 3 { header.configure(title: "Birders' Gossip") }
            return header
        }
         return UICollectionReusableView()
     }
}

extension HomeViewController {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !animatedIndexPaths.contains(indexPath) {            cell.alpha = 0; cell.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.5, delay: 0.02 * Double(indexPath.item), usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction], animations: { cell.alpha = 1; cell.transform = .identity }, completion: { _ in self.animatedIndexPaths.insert(indexPath) })
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let card = migrationCards[indexPath.row]
            let hotspot = card.hotspot
            let radius = max(2.0, hotspot.pinRadiusKm)
            
            let preds = hotspot.birdSpecies.map { sp in
                let bird = WatchlistManager.shared.findBird(byName: sp.birdName)
                
                let rawImage = sp.birdImageName
                let cleanImage = (rawImage == "placeholder_bird" || 
                                  rawImage == "placeholder_image" || 
                                  rawImage.isEmpty) ? nil : rawImage

                let remoteImage = cleanImage ?? bird?.imageUrl ?? bird?.staticImageName

                return FinalPredictionResult(
                    birdName: sp.birdName,
                    imageName: remoteImage ?? "placeholder_image",
                    likelySpot: bird?.likelySpot ?? "Sky",
                    matchedInputIndex: 0,
                    matchedLocation: (lat: hotspot.centerCoordinate.latitude, lon: hotspot.centerCoordinate.longitude),
                    spottingProbability: sp.sightabilityPercent,
                    weekNumber: sp.weekNumber,
                    residencyStatus: sp.residencyStatus,
                    ebirdSpeciesCode: sp.ebirdSpeciesCode ?? bird?.ebird_species_code,
                    weekScores: sp.weekScores,
                    peakWeek: sp.peakWeek
                )
            }
            
            // Get selected week from the cell
            let cell = collectionView.cellForItem(at: indexPath) as? NewMigrationCollectionViewCell
            let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
            let selectedWeek = cell?.selectedWeek ?? currentWeek
            let calendar = Calendar.current
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            components.weekOfYear = selectedWeek
            let weekStart = calendar.date(from: components) ?? Date()
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? Date()

            _ = navigateToSpotDetails(
                name: hotspot.placeName, 
                lat: hotspot.centerCoordinate.latitude, 
                lon: hotspot.centerCoordinate.longitude, 
                radius: radius, 
                predictions: preds,
                startDate: weekStart,
                endDate: weekEnd
            )
        case 1:
            if indexPath.row == 0 {
                didTapPredictBird()
                return
            }
            let adjustedRow = indexPath.row - 1
            if upcomingBirds.indices.contains(adjustedRow) {
                let uiBird = upcomingBirds[adjustedRow]
                
                // Try to find full Bird object for metadata, or build from UI bird
                if let forcedInput = mlPredictionInputsByBirdName[uiBird.title.lowercased()] {
                    navigateToBirdPrediction(input: forcedInput)
                } else {
                    let (start, end) = homeManager.parseDateRange(uiBird.date)
                    let sDate = start ?? Date()
                    let eDate = end ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: sDate) ?? sDate
                    
                    let birdId: String
                    if let bird = WatchlistManager.shared.findBird(byName: uiBird.title) {
                        birdId = bird.bird_id.uuidString
                    } else {
                        birdId = UUID().uuidString // Fallback for purely regional birds
                    }
                    
                    let input = BirdDateInput(
                        species: SpeciesData(
                            id: birdId,
                            name: uiBird.title,
                            imageName: uiBird.imageName,
                            ebirdSpeciesCode: uiBird.ebirdSpeciesCode
                        ),
                        startDate: sDate,
                        endDate: eDate
                    )
                    navigateToBirdPrediction(input: input)
                }
            }
        case 2:
            if indexPath.row == 0 {
                didTapPredictSpot()
                return
            }
            let adjustedRow = indexPath.row - 1
            guard spots.indices.contains(adjustedRow) else { return }
            let item = spots[adjustedRow]

            let initialPredictions: [FinalPredictionResult]
            if let edgeSpecies = item.edgeSpecies, !edgeSpecies.isEmpty {
                initialPredictions = homeManager.predictionResults(
                    from: edgeSpecies,
                    lat: item.latitude,
                    lon: item.longitude
                )
            } else {
                initialPredictions = []
            }

            let mapVC = navigateToSpotDetails(
                name: item.title,
                lat: item.latitude,
                lon: item.longitude,
                radius: item.radius,
                predictions: initialPredictions
            )

            // Refresh the already-visible screen when selected-hotspot data arrives.
            Task { @MainActor [weak self, weak mapVC] in
                guard let self = self else { return }
                
                let outputVC = mapVC?.children.first?.children.first as? PredictOutputViewController
                outputVC?.showUpdatingBanner()

                let preds = await self.homeManager.getSpeciesForHotspot(
                    lat: item.latitude,
                    lon: item.longitude,
                    hotspotId: item.hotspotId
                )
                
                if !preds.isEmpty {
                    mapVC?.refreshOutputPredictions(preds)
                }
                
                outputVC?.hideUpdatingBanner()
            }
        case 3:
            navigateToNewsArticle(newsItem(at: indexPath.row))
        default: break
        }
    }

    @objc private func stickyBirdButtonTapped() {
        didTapPredictBird()
    }

    @objc private func stickySpotButtonTapped() {
        didTapPredictSpot()
    }

    private func didTapPredictBird() {
        let storyboard = UIStoryboard(name: "Birdspred", bundle: nil)
        guard let selectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController else {
            return
        }
        
        let allSpeciesData = WatchlistManager.shared.fetchAllBirds()
        selectionVC.allSpecies = allSpeciesData.map {
            SpeciesData(
                id: $0.bird_id.uuidString, 
                name: $0.commonName, 
                imageName: $0.imageUrl ?? $0.staticImageName,
                ebirdSpeciesCode: $0.ebird_species_code
            )
        }
        let watchlistTitles = upcomingBirds.map { $0.title }
        let preSelectedIDs = allSpeciesData.filter { watchlistTitles.contains($0.commonName) }.map { $0.bird_id.uuidString }
        selectionVC.selectedSpecies = Set(preSelectedIDs)
        navigationController?.pushViewController(selectionVC, animated: true)
    }

    private func didTapPredictSpot() {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
            navigationController?.pushViewController(predictMapVC, animated: true)
        }
    }

    private func newsItem(at index: Int) -> NewsItem {
        return (!news.isEmpty && index >= 0 && index < news.count) ? news[index] : emptyNewsItem
    }

    @MainActor
    private func updateNewsPage(to page: Int) {
        let clampedPage = clampedNewsPage(page)
        guard currentNewsPage != clampedPage else { return }
        currentNewsPage = clampedPage

        if let footer = homeCollectionView.supplementaryView(
            forElementKind: "NewsPageControlFooter",
            at: IndexPath(item: 0, section: 3)
        ) as? PageControlReusableViewCollectionReusableView {
            footer.configure(
                numberOfPages: news.isEmpty ? 0 : min(news.count, 8),
                currentPage: currentNewsPage
            )
        }
    }

    private func clampedNewsPage(_ page: Int) -> Int {
        let maxPage = max((news.isEmpty ? 1 : min(news.count, 8)) - 1, 0)
        return min(max(page, 0), maxPage)
    }
}
