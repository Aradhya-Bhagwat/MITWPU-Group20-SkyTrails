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
	private func navigateToSpotDetails(name: String, lat: Double, lon: Double, radius: Double, birds: [SpotBird]) {
			
		var inputData = PredictionInputData()
		inputData.locationName = name
		inputData.latitude = lat
		inputData.longitude = lon
		inputData.areaValue = Int(radius)
		inputData.startDate = Date()
		inputData.endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
		
		let predictions: [FinalPredictionResult] = birds.map { bird in
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

        if section == 0 {
            return HomeManager.shared.getDynamicMapCards().count
        } else if section == 1 {
            return homeData.homeScreenBirds.count
        } else if section == 2 {
            return min(homeData.homeScreenSpots.count, 5)
        } else if section == 3 {
            return homeData.communityObservations.count
        } else if section == 4 {
            return homeData.latestNews.count
        }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
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
                let item = homeData.homeScreenBirds[indexPath.row]
                cell.configure(image: UIImage(named: item.imageName), title: item.title, date: item.date)
                return cell
            }else if indexPath.section == 2 {

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
                birdImage: UIImage(named: item.displayImageName)
            )
            return cell
        } else if indexPath.section == 4 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "NewsCollectionViewCell",
                for: indexPath
            ) as! NewsCollectionViewCell
            
            let item = homeData.latestNews[indexPath.row]
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
             
             let observationCount = homeData.communityObservations.count
             footer.configure(numberOfPages: observationCount, currentPage: 0)
             return footer
         }
         
         else if kind == newsFooterKind && indexPath.section == 4 {
             let footer = collectionView.dequeueReusableSupplementaryView(
                 ofKind: kind,
                 withReuseIdentifier: PageControlReusableViewCollectionReusableView.identifier,
                 for: indexPath
             ) as! PageControlReusableViewCollectionReusableView
             
             let count = homeData.latestNews.count
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
                let totalCount = homeData.communityObservations.count
                footer.configure(numberOfPages: totalCount, currentPage: indexPath.row)
            }
        }
        
        else if indexPath.section == 4 {
            let footerKind = "NewsPageControlFooter"
            
            if let footer = collectionView.supplementaryView(
                forElementKind: footerKind,
                at: IndexPath(item: 0, section: 4)
            ) as? PageControlReusableViewCollectionReusableView {
                let totalCount = homeData.latestNews.count
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
                if let species = PredictionEngine.shared.allSpecies.first(where: { $0.name == migration.birdName }) {
                    let (start, end) = HomeManager.shared.parseDateRange(migration.dateRange)
                    let input = BirdDateInput(
                        species: species,
                        startDate: start ?? Date(),
                        endDate: end ?? Date()
                    )
                    
                    let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
                    if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
                        mapVC.predictionInputs = [input]
                        self.navigationController?.pushViewController(mapVC, animated: true)
                    }
                }
            }
				
			case 1:
				let item = homeData.homeScreenBirds[indexPath.row]
				if let species = PredictionEngine.shared.allSpecies.first(where: { $0.name == item.title }) {
					let (start, end) = HomeManager.shared.parseDateRange(item.date)
					let input = BirdDateInput(
						species: species,
						startDate: start ?? Date(),
						endDate: end ?? Date()
					)
					
					let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
					if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
						mapVC.predictionInputs = [input]
						self.navigationController?.pushViewController(mapVC, animated: true)
					}
				}
				
			case 2:
				let item = homeData.homeScreenSpots[indexPath.row]
				guard let lat = item.latitude, let lon = item.longitude else { return }
				navigateToSpotDetails(
					name: item.title,
					lat: lat,
					lon: lon,
					radius: item.radius ?? 5.0,
					birds: item.birds ?? []
				)
				
			case 3:
				let observation = homeData.communityObservations[indexPath.row]
				let storyboard = UIStoryboard(name: "Home", bundle: nil)
				if let detailVC = storyboard.instantiateViewController(withIdentifier: "CommunityObservationViewController") as? CommunityObservationViewController {
					detailVC.observation = observation
					navigationController?.pushViewController(detailVC, animated: true)
				}
				
			case 4:
				let item = homeData.latestNews[indexPath.row]
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
