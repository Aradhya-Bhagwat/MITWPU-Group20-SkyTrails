//
//  AllUpcomingBirdsViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class AllUpcomingBirdsViewController: UIViewController {
    
    var watchlistData: [UpcomingBirdResult] = []
    var recommendationsData: [RecommendedBirdResult] = []
    
    private var cachedItemSize: NSCollectionLayoutSize?
        
    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
     
        super.viewDidLoad()
        self.title = "All Upcoming Birds"
        self.view.backgroundColor = .systemBackground
                
        setupNavigationBar()
        setupCollectionView()
    }
    
  
    private func setupCollectionView() {

        collectionView.collectionViewLayout = createLayout()
        
        collectionView.register(
            UINib(nibName: "GridUpcomingBirdCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: GridUpcomingGridCollectionViewCell.identifier
        )
        

        collectionView.register(
            UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderCollectionReusableView.identifier
        )
        
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    private func setupNavigationBar() {
            let predictImage = UIImage(named: "upcomingBirds")
            let predictButton = UIBarButtonItem(image: predictImage, style: .plain, target: self, action: #selector(didTapPredict))
            predictButton.tintColor = .systemBlue
            self.navigationItem.rightBarButtonItem = predictButton
        }
            
        @objc private func didTapPredict() {
        
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        guard let selectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController else {

            return
        }
        
        let allSpeciesData = WatchlistManager.shared.fetchAllBirds()
        selectionVC.allSpecies = allSpeciesData.map {
            SpeciesData(id: $0.id.uuidString, name: $0.commonName, imageName: $0.staticImageName)
        }
        let watchlistTitles = watchlistData.map { $0.bird.commonName }
        let preSelectedIDs = allSpeciesData.filter { watchlistTitles.contains($0.commonName) }.map { $0.id.uuidString }
        selectionVC.selectedSpecies = Set(preSelectedIDs)
        navigationController?.pushViewController(selectionVC, animated: true)
    }
        
    private func createLayout() -> UICollectionViewLayout {
            return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
                guard let self = self else { return nil }
            
                let containerWidth = layoutEnvironment.container.effectiveContentSize.width
                if self.cachedItemSize == nil {
                    guard let windowScene = self.view.window?.windowScene else { return nil }
                    let screenBounds = windowScene.screen.bounds
                    let portraitWidth = min(screenBounds.width, screenBounds.height)
                    let padding: CGFloat = 16.0
                    let spacing: CGFloat = 16.0
                    let maxCardWidth: CGFloat = 300.0
                    let minColumns = 2
            
                    var columnCount = minColumns
                    var calculatedWidth = (portraitWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                    
                    while calculatedWidth > maxCardWidth {
                        columnCount += 1
                        calculatedWidth = (portraitWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                    }
                    
                    let heightMultiplier: CGFloat = 91.0 / 88.0
                    let calculatedHeight = calculatedWidth * heightMultiplier
                    self.cachedItemSize = NSCollectionLayoutSize(
                        widthDimension: .absolute(calculatedWidth),
                        heightDimension: .absolute(calculatedHeight)
                    )
                }
                guard let fixedSize = self.cachedItemSize else { return nil }
                let itemWidth = fixedSize.widthDimension.dimension
                let interItemSpacing: CGFloat = 8
                let estimatedColumns = Int((containerWidth + interItemSpacing) / (itemWidth + interItemSpacing))
                let actualColumns = max(1, estimatedColumns)
                let groupItemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0/CGFloat(actualColumns)),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: groupItemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
                
                let groupHeight = fixedSize.heightDimension.dimension
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(groupHeight)
                )
                
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 24, trailing: 8)
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(44))
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                
                return section
            }
        }
    }

extension AllUpcomingBirdsViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return watchlistData.count }
        else { return recommendationsData.count }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GridUpcomingGridCollectionViewCell.identifier,
            for: indexPath
        ) as? GridUpcomingGridCollectionViewCell else {
            return UICollectionViewCell()
        }

        if indexPath.section == 0 {
            let item = watchlistData[indexPath.row]
            let upcomingBird = UpcomingBird(
                imageName: item.bird.staticImageName,
                title: item.bird.commonName,
                date: item.statusText
            )
            cell.configure(with: upcomingBird)
        } else {
            let result = recommendationsData[indexPath.row]
            let upcomingBird = UpcomingBird(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.dateRange
            )
            cell.configure(with: upcomingBird)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier, for: indexPath) as? SectionHeaderCollectionReusableView else {
            return UICollectionReusableView()
        }
        
        if indexPath.section == 0 {
            header.isHidden = watchlistData.isEmpty
            header.configure(title: "Your Bird Watchlist")
        } else {
            header.isHidden = false
            header.configure(title: "Recommended Birds")
        }
        return header
    }
}

extension AllUpcomingBirdsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate) ?? startDate

        if indexPath.section == 0 {
            let item = watchlistData[indexPath.row]
            let input = BirdDateInput(
                species: SpeciesData(id: item.bird.id.uuidString, name: item.bird.commonName, imageName: item.bird.staticImageName),
                startDate: startDate,
                endDate: endDate
            )
            if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
                mapVC.predictionInputs = [input]
                self.navigationController?.pushViewController(mapVC, animated: true)
            }
        } else {
            let result = recommendationsData[indexPath.row]
            let input = BirdDateInput(
                species: SpeciesData(id: result.bird.id.uuidString, name: result.bird.commonName, imageName: result.bird.staticImageName),
                startDate: startDate,
                endDate: endDate
            )
            if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
                mapVC.predictionInputs = [input]
                self.navigationController?.pushViewController(mapVC, animated: true)
            }
        }
    }
}
