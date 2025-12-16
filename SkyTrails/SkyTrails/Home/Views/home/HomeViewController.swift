//
//  HomeViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var homeCollectionView: UICollectionView!
    

    let homeData = HomeModels()
    private var cachedUpcomingBirdCardWidth: CGFloat?
    private var cachedSpotsCardWidth: CGFloat?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Home"
        self.navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        setupCollectionView()        // Do any additional setup after loading the view.
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: { _ in
                self.homeCollectionView.collectionViewLayout.invalidateLayout()
            }, completion: nil)
        }
    // Add this inside HomeViewController class
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAllSpots" {
            if let destinationVC = segue.destination as? AllSpotsViewController {
                destinationVC.watchlistData = homeData.watchlistSpots
                destinationVC.recommendationsData = homeData.recommendedSpots
            }
        }
        
        if segue.identifier == "ShowAllBirds" {
            if let destinationVC = segue.destination as? AllUpcomingBirdsViewController {
                destinationVC.watchlistData = homeData.watchlistBirds
                destinationVC.recommendationsData = homeData.recommendedBirds
            }
        }
    }
}
// HomeViewController.swift
extension HomeViewController {
    func setupCollectionView() {
            homeCollectionView.delegate = self
            homeCollectionView.dataSource = self
            homeCollectionView.backgroundColor = .white
            
            // 1. Register Cells (Existing Logic)
        homeCollectionView.register(
            UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil),
            forSupplementaryViewOfKind: "CommunityPageControlFooter",
            withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier
        )
        homeCollectionView.register(
                UINib(nibName: PageControlReusableViewCollectionReusableView.identifier, bundle: nil),
                forSupplementaryViewOfKind: "MigrationPageControlFooter", // ⬅️ THIS IS THE ELEMENT KIND
                withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier
            )
            homeCollectionView.register(
                UINib(nibName: "q_2UpcomingBirdsCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "q_2UpcomingBirdsCollectionViewCell"
            )
            homeCollectionView.register(
                UINib(nibName: "q_3SpotsToVisitCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "q_3SpotsToVisitCollectionViewCell"
            )
        
            homeCollectionView.register(
                    UINib(nibName: q_4CommunityObservationsCollectionViewCell.identifier, bundle: nil),
                    forCellWithReuseIdentifier: q_4CommunityObservationsCollectionViewCell.identifier
                )
        
        homeCollectionView.register(
                    UINib(nibName: MigrationCellCollectionViewCell.identifier, bundle: nil),
                    forCellWithReuseIdentifier: MigrationCellCollectionViewCell.identifier
                )
        
        homeCollectionView.register(
            UINib(nibName: HotspotCellCollectionViewCell.identifier, bundle: nil),
            forCellWithReuseIdentifier: HotspotCellCollectionViewCell.identifier
        )
        
            homeCollectionView.register(
                    UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil),
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: SectionHeaderCollectionReusableView.identifier // Use the static identifier
                )
           
            // 3. Apply Layout
            homeCollectionView.collectionViewLayout = createLayout()
            
    }
    
    // Change createLayout to return the layout based on the section index
    private func createLayout() -> UICollectionViewLayout {
        
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            
            switch sectionIndex {
            case 0: // Migration Map Carousel
                return self.createMigrationCarouselSection()
            case 1: // Upcoming Birds
                return self.createUpcomingBirdsSection()
            case 2: // Spots to Visit
                return self.createSpotsToVisitSection()
            case 3: // ⭐️ SHIFTED & ADDED: Community Observations (was 2) ⭐️
                return self.createCommunityObservationsSection() // Ensure this helper exists
            default:
                return nil // Safely return nil for unexpected indices
            }
        }
        
        layout.configuration.contentInsetsReference = .automatic
        return layout
    }
    
    
    private func createSectionHeaderLayout() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(40) // Define a fixed height for the header
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        // Add horizontal padding to align with section content
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16)
        
        return header
    }
    
    
    // --- Section 0: Upcoming Birds (Horizontal) ---
    private func createUpcomingBirdsSection() -> NSCollectionLayoutSection {
        let cardWidth: CGFloat
        
        if let cached = cachedUpcomingBirdCardWidth {
            cardWidth = cached
        } else {
            let interGroupSpacing: CGFloat = 16
            let outerPadding: CGFloat = 16 * 2
            let visibleCardProportion: CGFloat = 2.1
            
            let screenWidth = UIScreen.main.bounds.width
            let numberOfSpacings = floor(visibleCardProportion)
            let totalSpacing = (numberOfSpacings * interGroupSpacing) + outerPadding
            
            cardWidth = (screenWidth - totalSpacing) / visibleCardProportion
            
            cachedUpcomingBirdCardWidth = cardWidth
        }
       
        // 2. Layout
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cardWidth),
            heightDimension: .absolute(cardWidth * 1.034)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 16
        
        // header
        section.boundarySupplementaryItems = [createSectionHeaderLayout()]
        
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 16,
            bottom: 20,
            trailing: 16
        )
        
        return section
    }

    
    // --- Section 1: Spots to Visit (Vertical Grid) 💡 NEW ---
    private func createSpotsToVisitSection() -> NSCollectionLayoutSection {
        // Item takes up half the width of the group
        let cardWidth: CGFloat
            
            if let cached = cachedSpotsCardWidth {
                cardWidth = cached
            } else {
                let interGroupSpacing: CGFloat = 16
                let outerPadding: CGFloat = 16 * 2
                let visibleCardProportion: CGFloat = 2.1
                
                let screenWidth = UIScreen.main.bounds.width
                let numberOfSpacings = floor(visibleCardProportion)
                let totalSpacing = ((numberOfSpacings) * interGroupSpacing) + outerPadding
                
                cardWidth = (screenWidth - totalSpacing) / visibleCardProportion
                
                cachedSpotsCardWidth = cardWidth
            }
            
            // 2. Layout
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cardWidth),
                heightDimension: .absolute(cardWidth * 1.034)
            )
            
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )
            
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 16
            
            // header
            section.boundarySupplementaryItems = [createSectionHeaderLayout()]
            
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 8,
                leading: 16,
                bottom: 20,
                trailing: 16
            )
            
            return section
        }
    // In HomeViewController.swift -> createMigrationCarouselSection()


    private func createCommunityObservationsSection() -> NSCollectionLayoutSection {
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            // Group takes full section width, fixed height for the card
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(159))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            
            let section = NSCollectionLayoutSection(group: group)
            
            // KEY FOR SWIPING: Full-page horizontal scrolling
            section.orthogonalScrollingBehavior = .groupPagingCentered
            section.interGroupSpacing = 0
        let pageControlFooterKind = "CommunityPageControlFooter"
            
            let pageControlFooterSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(30) // Fixed height for the Page Control area
            )
            
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        let pageControlFooter = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: pageControlFooterSize,
                    elementKind: pageControlFooterKind,
                    alignment: .bottom
                )// Added bottom padding for page control area
            
            // Attach header
            let header = createSectionHeaderLayout()
            section.boundarySupplementaryItems = [header,pageControlFooter]
            
            return section
        }
}


// MARK: - UICollectionView DataSource
extension HomeViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // This must match the number of sections defined in createLayout()
        return 4
    }
    
    // In HomeViewController.swift -> extension HomeViewController: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {

        if section == 0 {
            // ✅ FIX 1: Return the total count of ALL dynamic map cards (Migration + Hotspot)
            return homeData.getDynamicMapCards().count
        } else if section == 1 {
            // SHIFTED: Upcoming Birds
            return homeData.homeScreenBirds.count
        } else if section == 2 {
            // SHIFTED: Spots to Visit
            return min(homeData.homeScreenSpots.count, 5)
        } else if section == 3 {
            // SHIFTED: Community Observations
            return homeData.communityObservations.count
        }
        return 0
    }
    
    // In HomeViewController.swift -> extension HomeViewController: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.section == 0 {
            // ✅ FIX 2: Handle both Migration and Hotspot Cells via switch statement
            
            let mapCard = homeData.getDynamicMapCards()[indexPath.row]
            
            switch mapCard {
            
            case .migration(let migrationData):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: MigrationCellCollectionViewCell.identifier,
                    for: indexPath
                ) as? MigrationCellCollectionViewCell else { fatalError("Migration Cell failure") }
                
                // Configure the Migration Cell
                cell.configure(with: migrationData)
                return cell
                
            case .hotspot(let hotspotData):
                // Dequeue the Hotspot Cell
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: HotspotCellCollectionViewCell.identifier, // Assuming this matches your registration
                    for: indexPath
                ) as? HotspotCellCollectionViewCell else { fatalError("Hotspot Cell failure") }
                
                // Configure the Hotspot Cell
                cell.configure(with: hotspotData)
                return cell
            }
        } else if indexPath.section == 1 {
            // SHIFTED: --- SECTION 1: UPCOMING BIRDS (was 0) ---
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "q_2UpcomingBirdsCollectionViewCell",
                for: indexPath
            ) as! q_2UpcomingBirdsCollectionViewCell
            
            let item = homeData.homeScreenBirds[indexPath.row]
            cell.configure(
                image: UIImage(named: item.imageName),
                title: item.title,
                date: item.date
            )
            return cell
            
        } else if indexPath.section == 2 {
            // SHIFTED: --- SECTION 2: SPOTS TO VISIT (was 1) ---
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "q_3SpotsToVisitCollectionViewCell",
                for: indexPath
            ) as! q_3SpotsToVisitCollectionViewCell
            
            let item = homeData.homeScreenSpots[indexPath.row]
            cell.configure(
                image: UIImage(named: item.imageName),
                title: item.title,
                date: item.location
            )
            return cell
            
        } else if indexPath.section == 3 {
            // SHIFTED: --- SECTION 3: COMMUNITY OBSERVATIONS (was 2) ---
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: q_4CommunityObservationsCollectionViewCell.identifier,
                for: indexPath
            ) as! q_4CommunityObservationsCollectionViewCell
            
            let item = homeData.communityObservations[indexPath.row]
            cell.configure(
                with: item,
                birdImage: UIImage(named: item.imageName)
            )
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                         viewForSupplementaryElementOfKind kind: String,
                         at indexPath: IndexPath) -> UICollectionReusableView {
         
         let communityFooterKind = "CommunityPageControlFooter"
         let migrationFooterKind = "MigrationPageControlFooter"
         
         // 🔑 HANDLE PAGE CONTROL FOOTER FOR SECTION 0 (Migration/Hotspot Carousel)
         if kind == migrationFooterKind && indexPath.section == 0 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
             // Configure the number of pages based on ALL dynamic map cards
             let totalMapCardCount = homeData.getDynamicMapCards().count
             // Start on the first page (index 0)
             footer.configure(numberOfPages: totalMapCardCount, currentPage: 0)
             return footer
         }
         
         // 🔑 HANDLE PAGE CONTROL FOOTER FOR SECTION 3 (Community)
         else if kind == communityFooterKind && indexPath.section == 3 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
             let observationCount = homeData.communityObservations.count
             // Start on the first page (index 0)
             footer.configure(numberOfPages: observationCount, currentPage: 0)
             return footer
         }
         
         // HANDLE SECTION HEADERS
        // ... inside viewForSupplementaryElementOfKind ...

        // HANDLE SECTION HEADERS
        else if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderCollectionReusableView.identifier,
                for: indexPath
            ) as! SectionHeaderCollectionReusableView
            
            // Variable to hold the specific action for the current section
            var action: (() -> Void)? = nil
            
            // Configure based on section index
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

                
                // ⭐️ SECTION 2 LOGIC: Navigate using Storyboard Segue
                action = { [weak self] in
                        guard let self = self else { return }

                        
                        self.performSegue(withIdentifier: "ShowAllSpots", sender: nil)
                    }
                header.configure(title: "Spots to Visit", tapAction: action)
            }
            else if indexPath.section == 3 {
                header.configure(title: "Community Observations")
            }
            
            return header
        }
         return UICollectionReusableView()
     }
}

// In HomeViewController.swift

// Note: willDisplay is actually part of UICollectionViewDelegate, so we can just use that extension.
// If you have a separate extension for UIScrollViewDelegate, replace it with this:

extension HomeViewController {
    
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        
        // 1. Check if we are in Section 0 (Migration/Hotspot Map)
        if indexPath.section == 0 {
            let footerKind = "MigrationPageControlFooter"
            
            // Try to retrieve the visible footer for Section 0
            if let footer = collectionView.supplementaryView(
                forElementKind: footerKind,
                at: IndexPath(item: 0, section: 0)
            ) as? PageControlReusableViewCollectionReusableView {
                
                // Get the total count of map cards
                let totalCount = homeData.getDynamicMapCards().count
                
                // Update the Page Control to the current row index
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
        
        // 2. Check if we are in Section 3 (Community Observations)
        else if indexPath.section == 3 {
            let footerKind = "CommunityPageControlFooter"
            
            if let footer = collectionView.supplementaryView(
                forElementKind: footerKind,
                at: IndexPath(item: 0, section: 3)
            ) as? PageControlReusableViewCollectionReusableView {
                
                let totalCount = homeData.communityObservations.count
                
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // Handle "Spots to Visit" Selection
        if indexPath.section == 2 {
            let item = homeData.homeScreenSpots[indexPath.row]

            
            guard let lat = item.latitude, let lon = item.longitude else {
    
                return
            }
            
            // 1. Create Input Data
            var inputData = PredictionInputData()
            inputData.locationName = item.title
            inputData.latitude = lat
            inputData.longitude = lon
            inputData.areaValue = Int(item.radius ?? 5.0)
            inputData.startDate = Date()
            inputData.endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
            
            // 2. Create Predictions
            let predictions: [FinalPredictionResult] = (item.birds ?? []).map { bird in
                return FinalPredictionResult(
                    birdName: bird.name,
                    imageName: bird.imageName,
                    matchedInputIndex: 0,
                    matchedLocation: (lat: bird.lat, lon: bird.lon)
                )
            }
            
            // 3. Navigate
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
                
                self.navigationController?.pushViewController(predictMapVC, animated: true)
                
                predictMapVC.loadViewIfNeeded()
                predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
            }
        } else if indexPath.section == 3 {
            let observation = homeData.communityObservations[indexPath.row]
            
            // Create a Bird object from CommunityObservation data
            let bird = Bird(
                id: UUID(), // Generate a new UUID for the bird
                name: observation.birdName,
                scientificName: "Unknown", // Scientific name is not available in CommunityObservation
                images: [observation.imageName],
                rarity: [.common], // Default to common rarity
                location: [observation.location],
                date: [Date()], // Use current date as observation date is not available
                observedBy: [observation.user.profileImageName],
                notes: nil // No notes available in CommunityObservation
            )
            
            let watchlistStoryboard = UIStoryboard(name: "Watchlist", bundle: nil)
            if let observedDetailVC = watchlistStoryboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as? ObservedDetailViewController {
                observedDetailVC.bird = bird
                observedDetailVC.watchlistId = nil // Community observations are not tied to a specific watchlist ID here
                navigationController?.pushViewController(observedDetailVC, animated: true)
            }
        }
    }

        
       
        
    
    // 💡 NEW: Handle Page Control updates on scroll
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        
//        
//        let targetSectionIndex = 2
//
//     
//        guard scrollView == homeCollectionView else { return }
//        
//     
//        for subview in homeCollectionView.subviews {
//            if let internalCollectionView = subview as? UICollectionView {
//                if internalCollectionView.collectionViewLayout.collectionView?.collectionViewLayout is UICollectionViewCompositionalLayout,
//                   let sectionLayout = internalCollectionView.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)) {
// 
//                    let contentOffsetX = internalCollectionView.contentOffset.x
//                
//                    let pageWidth = internalCollectionView.bounds.width
//    
//                    let currentPage = Int(round(contentOffsetX / pageWidth))
//           
//                    if currentPage != pageControl.currentPage && currentPage >= 0 && currentPage < pageControl.numberOfPages {
//                        pageControl.currentPage = currentPage
//                    }
//                    return
//                }
//            }
//        }
//    }
}

// MARK: - Layout Helpers
extension HomeViewController {
    
    // ... [existing setupCollectionView and createLayout functions] ...

    // --- Section 0: Migration Map Carousel (Horizontal Scrolling) ---
    private func createMigrationCarouselSection() -> NSCollectionLayoutSection {
        
        // 1. Item Definition (Card Size)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        // 2. Group Definition (The viewing window for one card)
        let groupWidth = 0.9 // Card fills 90% of the screen width
        let groupHeight: CGFloat = 320 // Fixed height for the map card
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(groupWidth),
            heightDimension: .absolute(groupHeight) // Set absolute height
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        // 3. Section Definition (Horizontal Scroll)
        // FIX 1: Explicitly cast group to NSCollectionLayoutGroup
        let section = NSCollectionLayoutSection(group: group as! NSCollectionLayoutGroup)
        
        // FIX 2: Access the scrolling constant directly on NSCollectionLayoutSection
        section.orthogonalScrollingBehavior = .groupPagingCentered
        // Define the Page Control Footer
        
        
        let migrationPageControlFooterKind = "MigrationPageControlFooter"
        
        let pageControlFooterSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(30)
        )
        
        let pageControlFooter = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: pageControlFooterSize,
            elementKind: migrationPageControlFooterKind,
            alignment: .bottom
        )
      
        
        // Attach the footer to the section
        section.boundarySupplementaryItems = [pageControlFooter]
        
        let header = createSectionHeaderLayout()
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        section.boundarySupplementaryItems = [header, pageControlFooter]
        
        // Spacing and Insets
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 20, trailing: 0)
        
        return section
    }    // ... [rest of the existing layout helper functions: createSectionHeaderLayout, createUpcomingBirdsSection, etc.] ...
}
