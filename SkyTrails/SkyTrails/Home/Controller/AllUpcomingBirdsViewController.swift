//
//  AllUpcomingBirdsViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class AllUpcomingBirdsViewController: UIViewController {
    
    var watchlistData: [UpcomingBird] = []
    var recommendationsData: [UpcomingBird] = []
    
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
    // MARK: - 1. Setup Navigation
    private func setupNavigationBar() {
            let predictButton = UIBarButtonItem(title: "Predict", style: .plain, target: self, action: #selector(didTapPredict))
            self.navigationItem.rightBarButtonItem = predictButton
        }
            
        @objc private func didTapPredict() {
        
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        guard let selectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController else {

            return
        }
        
         let allSpeciesData = PredictionEngine.shared.allSpecies
        selectionVC.allSpecies = allSpeciesData
        let watchlistTitles = watchlistData.map { $0.title }
        let preSelectedIDs = allSpeciesData.filter { watchlistTitles.contains($0.name) }.map { $0.id }
        selectionVC.selectedSpecies = Set(preSelectedIDs)
        navigationController?.pushViewController(selectionVC, animated: true)
    }
        
    // MARK: - 3. Dynamic Ratio Layout Logic (Same as AllSpots)
    private func createLayout() -> UICollectionViewLayout {
            return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
                guard let self = self else { return nil }
            
                let containerWidth = layoutEnvironment.container.effectiveContentSize.width
                if self.cachedItemSize == nil {
                    guard let windowScene = self.view.window?.windowScene else { return nil }
                    let screenBounds = windowScene.screen.bounds
                    let portraitWidth = min(screenBounds.width, screenBounds.height)
                    
                    // 2. Constants used for Portrait Layout
                    let padding: CGFloat = 16.0
                    let spacing: CGFloat = 16.0
                    let maxCardWidth: CGFloat = 300.0
                    let minColumns = 2
                    
                    // 3. Calculate what the width WOULD be in Portrait
                    var columnCount = minColumns
                    var calculatedWidth = (portraitWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                    
                    while calculatedWidth > maxCardWidth {
                        columnCount += 1
                        calculatedWidth = (portraitWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                    }
                    
                    // 4. Set the fixed Aspect Ratio (195/176)
                    let heightMultiplier: CGFloat = 195.0 / 176.0
                    let calculatedHeight = calculatedWidth * heightMultiplier
                    
                    // 5. Cache this size forever for this session
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
                    heightDimension: .absolute(groupHeight) // Keep height fixed
                )
                
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 24, trailing: 8)
                
                // Header
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

// MARK: - DataSource
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

        let item = (indexPath.section == 0) ? watchlistData[indexPath.row] : recommendationsData[indexPath.row]
        
        cell.configure(with: item)
        
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
        let item = (indexPath.section == 0) ? watchlistData[indexPath.row] : recommendationsData[indexPath.row]
        
        // 1. Find matching SpeciesData
        if let species = PredictionEngine.shared.allSpecies.first(where: { $0.name == item.title }) {
            
            // 2. Parse Date
            let (start, end) = HomeManager.shared.parseDateRange(item.date)
            
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
        }
    }
}
