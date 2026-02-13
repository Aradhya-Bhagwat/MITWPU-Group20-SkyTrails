//
//  HomeViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit
import CoreLocation

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var homeCollectionView: UICollectionView!
    

    private let homeManager = HomeManager.shared
    private var homeScreenData: HomeScreenData?

    // UI Data (converted for collection view)
    private var upcomingBirds: [UpcomingBirdUI] = []
    private var spots: [PopularSpotUI] = []
    private var observations: [CommunityObservation] = []
    private var news: [NewsItem] = []

    private var cachedUpcomingBirdCardWidth: CGFloat?
    private var cachedSpotsCardWidth: CGFloat?
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        self.title = "Home"
        self.navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        applySemanticAppearance()
        setupCollectionView()
        loadHomeData()
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
        // Refresh data when returning to screen
        refreshHomeData()
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
            UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil),
            forSupplementaryViewOfKind: "MigrationPageControlFooter",
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
            UINib(nibName: newMigrationCollectionViewCell.identifier, bundle: nil),
            forCellWithReuseIdentifier: newMigrationCollectionViewCell.identifier
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

    // MARK: - Data Loading

    private func loadHomeData() {
        Task { @MainActor in
            print("🔄 [HomeViewController] loadHomeData started")
            
            // Get user location (implement based on your LocationService)
            let userLocation = getUserLocation()
            print("📍 [HomeViewController] User location: \(String(describing: userLocation))")

            // Load all home screen data
            homeScreenData = await homeManager.getHomeScreenData(userLocation: userLocation)

            // Convert to UI models
            convertToUIModels()
            
            // Get migration cards count
            let migrationCards = homeManager.getDynamicMapCards()
            
            // Enhanced debug logging
            print("\n" + String(repeating: "=", count: 60))
            print("📊 [HomeViewController] HOME SCREEN DATA SUMMARY")
            print(String(repeating: "=", count: 60))
            print("   📅 Current week: \(Calendar.current.component(.weekOfYear, from: Date()))")
            print("   🗓️  Current date: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))")
            print("\n   Section 0 - Migration Cards: \(migrationCards.count)")
            if migrationCards.isEmpty {
                print("      ⚠️  WARNING: No migration cards - section 0 will be empty!")
            } else {
                for (index, card) in migrationCards.enumerated() {
                    switch card {
                    case .combined(let migration, let hotspot):
                        print("      [\(index)] \(migration.birdName)")
                        print("          Progress: \(Int(migration.currentProgress * 100))%")
                        print("          Path points: \(migration.pathCoordinates.count)")
                        print("          Hotspot: \(hotspot.placeName)")
                    }
                }
            }
            print("\n   Section 1 - Upcoming Birds: \(upcomingBirds.count)")
            print("   Section 2 - Spots: \(spots.count)")
            print("   Section 3 - Observations: \(observations.count)")
            print("   Section 4 - News: \(news.count)")
            print(String(repeating: "=", count: 60) + "\n")

            // Reload collection view
            print("🔄 [HomeViewController] Reloading collection view...")
            homeCollectionView.reloadData()
            print("✅ [HomeViewController] Collection view reloaded")
        }
    }

    private func refreshHomeData() {
        Task { @MainActor in
            let userLocation = getUserLocation()
            homeScreenData = await homeManager.getHomeScreenData(userLocation: userLocation)
            convertToUIModels()
            homeCollectionView.reloadData()
        }
    }

    private func getUserLocation() -> CLLocationCoordinate2D? {
        // Option 1: Use current GPS location
        // return LocationService.shared.currentLocation

        // Option 2: Use saved home location
        if let homeLocation = LocationPreferences.shared.homeLocation {
            return homeLocation
        }

        // Option 3: Fallback to Pune for testing
        return CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    }

    private func convertToUIModels() {
        guard let data = homeScreenData else { return }

        print("[upcomingbirdsdebug] HomeViewController.convertToUIModels: Received data")
        print("[upcomingbirdsdebug] - My watchlist birds count: \(data.myWatchlistBirds.count)")
        print("[upcomingbirdsdebug] - Recommended birds count: \(data.recommendedBirds.count)")

        // Convert MY watchlist birds (present at location, to_observe only)
        let watchlistUI = data.myWatchlistBirds.map { result in
            UpcomingBirdUI(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.statusText
            )
        }

        // Convert recommended birds (all birds at location)
        let recommendedUI = data.recommendedBirds.map { result in
            UpcomingBirdUI(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.dateRange
            )
        }
        
        // Option B: Fill with watchlist birds first, then add recommended to reach 6 total
        var combinedBirds: [UpcomingBirdUI] = []
        
        // Add all watchlist birds (up to 6)
        combinedBirds.append(contentsOf: watchlistUI.prefix(6))
        
        // Fill remaining slots with recommended birds
        let remainingSlots = 6 - combinedBirds.count
        if remainingSlots > 0 {
            // Filter out recommended birds that are already in watchlist (by name to avoid duplicates)
            let watchlistBirdNames = Set(watchlistUI.map { $0.title })
            let uniqueRecommended = recommendedUI.filter { !watchlistBirdNames.contains($0.title) }
            
            combinedBirds.append(contentsOf: uniqueRecommended.prefix(remainingSlots))
        }
        
        upcomingBirds = combinedBirds
        
        print("[upcomingbirdsdebug] Total upcoming birds to display: \(upcomingBirds.count)")
        print("[upcomingbirdsdebug] - Watchlist: \(min(watchlistUI.count, 6)), Recommended: \(upcomingBirds.count - min(watchlistUI.count, 6))")


        // Convert spots
        spots = (data.watchlistSpots.isEmpty ? data.recommendedSpots : data.watchlistSpots)
            .map { spot in
                PopularSpotUI(
                    id: spot.id,
                    imageName: spot.imageName ?? "default_spot",
                    title: spot.title,
                    location: spot.location,
                    latitude: spot.latitude,
                    longitude: spot.longitude,
                    speciesCount: spot.speciesCount,
                    radius: spot.radius
                )
            }

        // Observations (already in correct format)
        observations = data.recentObservations

        // News - load separately if needed
        loadNews()
    }

    private func loadNews() {
        // Load from JSON like the seeder does
        guard let url = Bundle.main.url(forResource: "home_data", withExtension: "json") else {
            print("⚠️ [HomeViewController] Could not find home_data.json for news")
            news = []
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode(HomeJSONData.self, from: data)
            news = jsonData.latestNews ?? []
        } catch {
            print("⚠️ [HomeViewController] Failed to load news: \(error)")
            news = []
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
        print("🔍 [HomeVC] Navigating to prediction for \(bird.commonName) with statusText: \(statusText)")

        let (parsedStart, parsedEnd) = homeManager.parseDateRange(statusText)
        let startDate = parsedStart ?? Date()
        let endDate = parsedEnd ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate) ?? startDate

        print("🔍 [HomeVC] Parsed dates - Start: \(String(describing: parsedStart)), End: \(String(describing: parsedEnd))")
        print("🔍 [HomeVC] Final dates used - Start: \(startDate), End: \(endDate)")

        let input = BirdDateInput(
            species: SpeciesData(id: bird.id.uuidString, name: bird.commonName, imageName: bird.staticImageName),
            startDate: startDate,
            endDate: endDate
        )

        // Navigate to prediction map
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
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(120))
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
}

extension HomeViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {

        switch section {
        case 0: // Migration cards
            let count = homeManager.getDynamicMapCards().count
            print("[issue1] HomeVC: Section 0 items count: \(count)")
            return count
        case 1: // Upcoming birds
            return upcomingBirds.count
        case 2: // Spots
            return min(spots.count, 5)
        case 3: // Community observations
            return observations.count
        case 4: // News
            return news.count
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            print("[issue1] HomeVC: Dequeuing cell for section 0 row \(indexPath.row)")
            let cardType = HomeManager.shared.getDynamicMapCards()[indexPath.row]
            
            switch cardType {
            case .combined(let migration, let hotspot):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: newMigrationCollectionViewCell.identifier,
                    for: indexPath
                ) as! newMigrationCollectionViewCell
                
                cell.configure(migration: migration, hotspot: hotspot)
                return cell
            }
        }
        else if indexPath.section == 1 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UpcomingBirdsCollectionViewCell", for: indexPath) as! UpcomingBirdsCollectionViewCell
                let item = upcomingBirds[indexPath.row]
                cell.configure(image: UIImage(named: item.imageName), title: item.title, date: item.date)
                return cell
            }else if indexPath.section == 2 {

            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "SpotsToVisitCollectionViewCell",
                for: indexPath
            ) as! SpotsToVisitCollectionViewCell
            
            let item = spots[indexPath.row]
            cell.configure(
                image: UIImage(named: item.imageName),
                title: item.title,
                speciesCount: item.speciesCount
            )
            return cell
            
        } else if indexPath.section == 3 {
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
        } else if indexPath.section == 4 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "NewsCollectionViewCell",
                for: indexPath
            ) as! NewsCollectionViewCell
            
            let item = news[indexPath.row]
            cell.configure(with: item)
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                         viewForSupplementaryElementOfKind kind: String,
                         at indexPath: IndexPath) -> UICollectionReusableView {
         
         let communityFooterKind = "CommunityPageControlFooter"
         let migrationFooterKind = "MigrationPageControlFooter"
         let newsFooterKind = "NewsPageControlFooter"
         
   
         if kind == migrationFooterKind && indexPath.section == 0 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
     
             let totalMapCardCount = HomeManager.shared.getDynamicMapCards().count
   
             footer.configure(numberOfPages: totalMapCardCount, currentPage: 0)
             return footer
         }
         
    
         else if kind == communityFooterKind && indexPath.section == 3 {
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
             
             let count = news.count
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
        if indexPath.section == 0 {
            let footerKind = "MigrationPageControlFooter"
            
            if let footer = collectionView.supplementaryView(
                forElementKind: footerKind,
                at: IndexPath(item: 0, section: 0)
            ) as? PageControlReusableViewCollectionReusableView {
                let totalCount = HomeManager.shared.getDynamicMapCards().count
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
        
        else if indexPath.section == 3 {
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
                let totalCount = news.count
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let cardData = HomeManager.shared.getDynamicMapCards()[indexPath.row]
            
            switch cardData {
            case .combined(let migration, _):
                guard let bird = WatchlistManager.shared.findBird(byName: migration.birdName) else { return }
                let (start, end) = homeManager.parseDateRange(migration.dateRange)
                let input = BirdDateInput(
                    species: SpeciesData(id: bird.id.uuidString, name: bird.commonName, imageName: bird.staticImageName),
                    startDate: start ?? Date(),
                    endDate: end ?? Date()
                )

                let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
                if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
                    mapVC.predictionInputs = [input]
                    self.navigationController?.pushViewController(mapVC, animated: true)
                }
            }
				
			case 1:
				let item = upcomingBirds[indexPath.row]
				
				// Determine source object (Watchlist vs Recommended)
                let watchlistCount = homeScreenData?.myWatchlistBirds.count ?? 0
                
                let bird: Bird
                let statusText: String
                
                if indexPath.row < watchlistCount {
                    // It's a watchlist item
                    guard let result = homeScreenData?.myWatchlistBirds[safe: indexPath.row] else { return }
                    bird = result.bird
                    statusText = result.statusText
                } else {
                    // It's a recommended item
                    let recommendedIndex = indexPath.row - watchlistCount
                    guard let recResult = homeScreenData?.recommendedBirds[safe: recommendedIndex] else { return }
                    bird = recResult.bird
                    statusText = recResult.dateRange
                }
				
				// Navigate to bird detail/map
				navigateToBirdPrediction(bird: bird, statusText: statusText)
				
			case 2:
				let item = spots[indexPath.row]
				
				// Get live predictions for this spot
				let predictions = homeManager.getLivePredictions(
					for: item.latitude,
					lon: item.longitude,
					radiusKm: item.radius
				)
				
				navigateToSpotDetails(
					name: item.title,
					lat: item.latitude,
					lon: item.longitude,
					radius: item.radius,
					predictions: predictions
				)
				
			case 3:
				let observation = observations[indexPath.row]
				let storyboard = UIStoryboard(name: "Home", bundle: nil)
				if let detailVC = storyboard.instantiateViewController(withIdentifier: "CommunityObservationViewController") as? CommunityObservationViewController {
					detailVC.observation = observation
					navigationController?.pushViewController(detailVC, animated: true)
				}
				
			case 4:
				let item = news[indexPath.row]
				if let url = URL(string: item.link) {
					UIApplication.shared.open(url)
				}
				
			default:
				break
		}
	}
    
}

extension HomeViewController {
    
    private func createMigrationCarouselSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let screenWidth = self.view.bounds.width
        let absoluteCardWidth = screenWidth - 32
        let calculatedHeight: CGFloat
        
        if screenWidth < 550 {
            calculatedHeight = absoluteCardWidth * (332.0 / 717.0)
        } else {
            calculatedHeight = absoluteCardWidth * (83.0 / 254.0)
        }

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(absoluteCardWidth),
            heightDimension: .absolute(calculatedHeight)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        let footerKind = "MigrationPageControlFooter"
        let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(30))
        let footer = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: footerSize, elementKind: footerKind, alignment: .bottom)
        
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 40
        section.boundarySupplementaryItems = [createSectionHeaderLayout(), footer]
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
        
        return section
    }
	
}

// MARK: - UI Models

struct UpcomingBirdUI {
    let imageName: String
    let title: String
    let date: String
}

struct PopularSpotUI {
    let id: UUID
    let imageName: String
    let title: String
    let location: String
    let latitude: Double
    let longitude: Double
    let speciesCount: Int
    let radius: Double
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
