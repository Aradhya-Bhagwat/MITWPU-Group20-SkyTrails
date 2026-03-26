import UIKit
import CoreLocation
import ImageIO

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var homeCollectionView: UICollectionView!
    
    private let homeManager = HomeManager.shared
    private var homeScreenData: HomeScreenData?
    private let profileLocationHeaderView = ProfileLocationHeaderView()
    private var profileLocationHeaderConstraints: [NSLayoutConstraint] = []
    private var upcomingBirds: [UpcomingBirdUI] = []
    private var spots: [PopularSpotUI] = []
    private var news: [NewsItem] = []
    private var migrationCards: [DynamicMapCard] = []

    private var animatedIndexPaths: Set<IndexPath> = []
    private var cachedUpcomingBirdCardWidth: CGFloat?
    private var cachedSpotsCardWidth: CGFloat?
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
        self.navigationItem.largeTitleDisplayMode = .automatic
        navigationController?.navigationBar.prefersLargeTitles = true
        view.sendSubviewToBack(homeCollectionView)
        homeCollectionView.contentInsetAdjustmentBehavior = .always
        setupProfileLocationHeaderView()
        setupLoadingIndicator()
        applySemanticAppearance()
        setupCollectionView()
        loadHomeData()
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
        attachProfileLocationHeaderViewIfNeeded()
        refreshHomeData()
        profileLocationHeaderView.refreshLocation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        profileLocationHeaderView.removeFromSuperview()
        NSLayoutConstraint.deactivate(profileLocationHeaderConstraints)
        profileLocationHeaderConstraints.removeAll()
    }
    
    @IBAction func profileTapped(_ sender: Any) {
        navigateToProfile()
    }

    // Configures the profile location header view in the navigation bar
    private func setupProfileLocationHeaderView() {
        profileLocationHeaderView.onTap = { [weak self] in
            self?.navigateToProfile()
        }
    }
    
    // Places the profile location header in the large title navigation bar area
    private func attachProfileLocationHeaderViewIfNeeded() {
        guard profileLocationHeaderView.superview == nil else { return }
        view.addSubview(profileLocationHeaderView)
        profileLocationHeaderConstraints = [
            profileLocationHeaderView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            profileLocationHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ]
        NSLayoutConstraint.activate(profileLocationHeaderConstraints)
    }



    private func navigateToProfile() {
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
            self.news = data.news
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
            self.news = data.news
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
    func numberOfSections(in collectionView: UICollectionView) -> Int { return 4 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return min(migrationCards.count, 1)
        case 1: return upcomingBirds.count; case 2: return min(spots.count, 5)
        case 3: return max(min(news.count, 8), 1)
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NewsCollectionViewCell", for: indexPath) as! NewsCollectionViewCell
            cell.configure(with: newsItem(at: indexPath.row)); return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
         if kind == "NewsPageControlFooter" {
             let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier, for: indexPath) as! PageControlReusableViewCollectionReusableView
             let count = news.isEmpty ? 0 : min(news.count, 8)
             footer.configure(numberOfPages: count, currentPage: 0); return footer
         } else if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier, for: indexPath) as! SectionHeaderCollectionReusableView
            if indexPath.section == 0 { header.configure(title: "Migration Forecast") }
            else if indexPath.section == 1 { header.configure(title: "Birding Highlights", tapAction: { [weak self] in self?.performSegue(withIdentifier: "ShowAllBirds", sender: nil) }) }
            else if indexPath.section == 2 { header.configure(title: "Top Birding Spots", tapAction: { [weak self] in self?.performSegue(withIdentifier: "ShowAllSpots", sender: nil) }) }
            else if indexPath.section == 3 { header.configure(title: "Birders' Gossip") }
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
        if indexPath.section == 3, let footer = collectionView.supplementaryView(forElementKind: "NewsPageControlFooter", at: IndexPath(item: 0, section: 3)) as? PageControlReusableViewCollectionReusableView {
            footer.configure(numberOfPages: news.isEmpty ? 0 : min(news.count, 8), currentPage: indexPath.row)
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
            let item = spots[indexPath.row]
            Task {
                let preds = if let edgeSpecies = item.edgeSpecies, !edgeSpecies.isEmpty {
                    homeManager.predictionResults(from: edgeSpecies, lat: item.latitude, lon: item.longitude)
                } else {
                    await homeManager.getLivePredictions(for: item.latitude, lon: item.longitude, radiusKm: item.radius)
                }

                await MainActor.run {
                    navigateToSpotDetails(name: item.title, lat: item.latitude, lon: item.longitude, radius: item.radius, predictions: preds)
                }
            }
        case 3:
            navigateToNewsArticle(newsItem(at: indexPath.row))
        default: break
        }
    }

    private func newsItem(at index: Int) -> NewsItem {
        return (!news.isEmpty && index >= 0 && index < news.count) ? news[index] : emptyNewsItem
    }
}
