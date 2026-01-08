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
        setupCollectionView()
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

extension HomeViewController {
    func setupCollectionView() {
            homeCollectionView.delegate = self
            homeCollectionView.dataSource = self
            homeCollectionView.backgroundColor = .white
            
     
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
                    withReuseIdentifier: SectionHeaderCollectionReusableView.identifier
                )

            homeCollectionView.collectionViewLayout = createLayout()
            
    }
    private func createLayout() -> UICollectionViewLayout {
        
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            
            switch sectionIndex {
            case 0: // Migration Map Carousel
                return self.createMigrationCarouselSection()
            case 1: // Upcoming Birds
                return self.createUpcomingBirdsSection()
            case 2: // Spots to Visit
                return self.createSpotsToVisitSection()
            case 3: // Community
                return self.createCommunityObservationsSection()
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
            let interGroupSpacing: CGFloat = 16
            let outerPadding: CGFloat = 16 * 2
            let visibleCardProportion: CGFloat = 2.1
            
            let screenWidth = self.view.bounds.width
            let numberOfSpacings = floor(visibleCardProportion)
            let totalSpacing = (numberOfSpacings * interGroupSpacing) + outerPadding
            
            let calculatedWidth = (screenWidth - totalSpacing) / visibleCardProportion
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

    
    private func createSpotsToVisitSection() -> NSCollectionLayoutSection {

        let cardWidth: CGFloat
            
            if let cached = cachedSpotsCardWidth {
                cardWidth = cached
            } else {
                let interGroupSpacing: CGFloat = 16
                let outerPadding: CGFloat = 16 * 2
                let visibleCardProportion: CGFloat = 2.1
                
                let screenWidth = self.view.bounds.width
                let numberOfSpacings = floor(visibleCardProportion)
                let totalSpacing = ((numberOfSpacings) * interGroupSpacing) + outerPadding
                
                let calculatedWidth = (screenWidth - totalSpacing) / visibleCardProportion
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
            
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )
            
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 16
            
            section.boundarySupplementaryItems = [createSectionHeaderLayout()]
            
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 8,
                leading: 16,
                bottom: 20,
                trailing: 16
            )
            
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
}


// MARK: - UICollectionView DataSource
extension HomeViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 4
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {

        if section == 0 {
            return homeData.getDynamicMapCards().count
        } else if section == 1 {
            return homeData.homeScreenBirds.count
        } else if section == 2 {
            return min(homeData.homeScreenSpots.count, 5)
        } else if section == 3 {
            return homeData.communityObservations.count
        }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.section == 0 {
            
            let mapCard = homeData.getDynamicMapCards()[indexPath.row]
            
            switch mapCard {
            
            case .migration(let migrationData):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: MigrationCellCollectionViewCell.identifier,
                    for: indexPath
                ) as? MigrationCellCollectionViewCell else { fatalError("Migration Cell failure") }
                
                cell.configure(with: migrationData)
                return cell
                
            case .hotspot(let hotspotData):
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: HotspotCellCollectionViewCell.identifier,
                    for: indexPath
                ) as? HotspotCellCollectionViewCell else { fatalError("Hotspot Cell failure") }

                cell.configure(with: hotspotData)
                return cell
            }
        } else if indexPath.section == 1 {

            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "UpcomingBirdsCollectionViewCell",
                for: indexPath
            ) as! UpcomingBirdsCollectionViewCell
            
            let item = homeData.homeScreenBirds[indexPath.row]
            cell.configure(
                image: UIImage(named: item.imageName),
                title: item.title,
                date: item.date
            )
            return cell
            
        } else if indexPath.section == 2 {

            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "SpotsToVisitCollectionViewCell",
                for: indexPath
            ) as! SpotsToVisitCollectionViewCell
            
            let item = homeData.homeScreenSpots[indexPath.row]
            cell.configure(
                image: UIImage(named: item.imageName),
                title: item.title,
                date: item.location
            )
            return cell
            
        } else if indexPath.section == 3 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CommunityObservationsCollectionViewCell.identifier,
                for: indexPath
            ) as! CommunityObservationsCollectionViewCell
            
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
         
   
         if kind == migrationFooterKind && indexPath.section == 0 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
     
             let totalMapCardCount = homeData.getDynamicMapCards().count
   
             footer.configure(numberOfPages: totalMapCardCount, currentPage: 0)
             return footer
         }
         
    
         else if kind == communityFooterKind && indexPath.section == 3 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
             let observationCount = homeData.communityObservations.count
             footer.configure(numberOfPages: observationCount, currentPage: 0)
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
            
            return header
        }
         return UICollectionReusableView()
     }
}


extension HomeViewController {
    
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        

        if indexPath.section == 0 {
            let footerKind = "MigrationPageControlFooter"
            
            // Try to retrieve the visible footer for Section 0
            if let footer = collectionView.supplementaryView(
                forElementKind: footerKind,
                at: IndexPath(item: 0, section: 0)
            ) as? PageControlReusableViewCollectionReusableView {
                
                let totalCount = homeData.getDynamicMapCards().count
                
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
        
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
        
        if indexPath.section == 1 {
            let item = homeData.homeScreenBirds[indexPath.row]
            
            // 1. Find matching SpeciesData
            if let species = PredictionEngine.shared.allSpecies.first(where: { $0.name == item.title }) {
                
                // 2. Parse Date
                let (start, end) = parseDateRange(item.date)
                
                // 3. Create Input
                let input = BirdDateInput(
                    species: species,
                    startDate: start ?? Date(),
                    endDate: end ?? Date()
                )
                
                // 4. Navigate
                let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
                if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
                    mapVC.predictionInputs = [input]
                    self.navigationController?.pushViewController(mapVC, animated: true)
                }
            } else {
                print("Species data not found for: \(item.title)")
                // Fallback or error handling if needed
            }
            
        } else if indexPath.section == 2 {
            let item = homeData.homeScreenSpots[indexPath.row]

            
            guard let lat = item.latitude, let lon = item.longitude else {
    
                return
            }
        
            var inputData = PredictionInputData()
            inputData.locationName = item.title
            inputData.latitude = lat
            inputData.longitude = lon
            inputData.areaValue = Int(item.radius ?? 5.0)
            inputData.startDate = Date()
            inputData.endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
            
            let predictions: [FinalPredictionResult] = (item.birds ?? []).map { bird in
                return FinalPredictionResult(
                    birdName: bird.name,
                    imageName: bird.imageName,
                    matchedInputIndex: 0,
                    matchedLocation: (lat: bird.lat, lon: bird.lon)
                )
            }
            
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
                
                self.navigationController?.pushViewController(predictMapVC, animated: true)
                
                predictMapVC.loadViewIfNeeded()
                predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
            }
        } else if indexPath.section == 3 {
            let observation = homeData.communityObservations[indexPath.row]
            
            let bird = Bird(
                id: UUID(),
                name: observation.birdName,
                scientificName: "Unknown",
                images: [observation.imageName],
                rarity: [.common],
                location: [observation.location],
                date: [Date()],
                observedBy: [observation.user.profileImageName],
                notes: nil
            )
            
            let watchlistStoryboard = UIStoryboard(name: "Watchlist", bundle: nil)
            if let observedDetailVC = watchlistStoryboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as? ObservedDetailViewController {
                observedDetailVC.bird = bird
                observedDetailVC.watchlistId = nil
                navigationController?.pushViewController(observedDetailVC, animated: true)
            }
        }
    }
    
    private func parseDateRange(_ dateString: String) -> (start: Date?, end: Date?) {
        let separators = [" – ", " - "]
        
        for separator in separators {
            let components = dateString.components(separatedBy: separator)
            if components.count == 2 {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMM ’yy"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                let start = formatter.date(from: components[0])
                let end = formatter.date(from: components[1])
                return (start, end)
            }
        }
        return (nil, nil)
    }
}

// MARK: - Layout Helpers
extension HomeViewController {
    
    // Inside HomeViewController.swift

    private func createMigrationCarouselSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let screenWidth = self.view.bounds.width
        let idealHeight = screenWidth * 0.8
        let clampedHeight = min(max(idealHeight, 320), 550)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.92),
            heightDimension: .absolute(clampedHeight) 
        )
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 12
        
        // Section and Header configuration
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
        
        let header = createSectionHeaderLayout()
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        section.boundarySupplementaryItems = [header, pageControlFooter]
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
        
        return section
    }
}
