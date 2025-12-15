//
//  AllUpcomingBirdsViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class AllUpcomingBirdsViewController: UIViewController {
    
    // Data Source
    var watchlistData: [UpcomingBird] = []
    var recommendationsData: [UpcomingBird] = []
    
    private var cachedItemSize: NSCollectionLayoutSize?
        
    // UI Elements
    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
     
        super.viewDidLoad()
        self.title = "All Upcoming Birds"
        self.view.backgroundColor = .systemBackground
                
        setupNavigationBar()
        setupCollectionView()
    }
    
  
    private func setupCollectionView() {
        // Initialize with Dynamic Layout
        collectionView.collectionViewLayout = createLayout()
        
        // ⭐️ REGISTER NEW CELL
        collectionView.register(
            UINib(nibName: UpcomingBirdGridCollectionViewCell.identifier, bundle: nil),
            forCellWithReuseIdentifier: UpcomingBirdGridCollectionViewCell.identifier
        )
        
        // Register Header
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
            // Add "Predict" button to Top Right
            let predictButton = UIBarButtonItem(title: "Predict", style: .plain, target: self, action: #selector(didTapPredict))
            self.navigationItem.rightBarButtonItem = predictButton
        }
            
        @objc private func didTapPredict() {
            print("Predict button tapped! (Navigate to Prediction Page later)")
            // TODO: Navigation to Prediction Page goes here
        }
        
    // MARK: - 3. Dynamic Ratio Layout Logic (Same as AllSpots)
    private func createLayout() -> UICollectionViewLayout {
            return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
                guard let self = self else { return nil }
                
                // Current available width of the screen
                let containerWidth = layoutEnvironment.container.effectiveContentSize.width
                
                // 1. Calculate the Fixed Card Size (Only once!)
                if self.cachedItemSize == nil {
                    
                    // Use the smallest dimension of the screen to calculate the "Base" layout
                    // This simulates "Portrait" width even if we launched in Landscape.
                    let screenMinDimension = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
                    
                    // Logic: Fit at least 2 columns in that min dimension, max width 400
                    let padding: CGFloat = 16.0 // Total padding
                    let spacing: CGFloat = 16.0 // Inter-item spacing
                    
                    let maxCardWidth: CGFloat = 400.0
                    let minColumns = 2
                    
                    var columnCount = minColumns
                    
                    // Simplified calculation for sizing width per item
                    var calculatedWidth = (screenMinDimension - (spacing * CGFloat(columnCount - 1)) - 16) / CGFloat(columnCount)
                    
                    // If cards are too big, add columns until they fit under maxWidth
                    while calculatedWidth > maxCardWidth {
                        columnCount += 1
                        calculatedWidth = (screenMinDimension - (spacing * CGFloat(columnCount - 1)) - 16) / CGFloat(columnCount)
                    }
                    
                    // Fixed Aspect Ratio: 176 : 195
                    let heightMultiplier: CGFloat = 195.0 / 176.0
                    let calculatedHeight = calculatedWidth * heightMultiplier
                    
                    // Store this "ideal" size
                    self.cachedItemSize = NSCollectionLayoutSize(
                        widthDimension: .absolute(calculatedWidth),
                        heightDimension: .absolute(calculatedHeight)
                    )
                    print("🔒 Fixed Bird Card Size Calculated: \(calculatedWidth) x \(calculatedHeight)")
                }
                
                // 2. Use Fixed Size to Layout Current Screen
                guard let fixedSize = self.cachedItemSize else { return nil }
                
                // Determine how many of these "Fixed Cards" fit in the CURRENT width
                let itemWidth = fixedSize.widthDimension.dimension
                let interItemSpacing: CGFloat = 8
                
                // Estimate columns based on current container width
                let estimatedColumns = Int((containerWidth + interItemSpacing) / (itemWidth + interItemSpacing))
                let actualColumns = max(1, estimatedColumns) // Ensure at least 1 column
                
                // 3. Build Layout Group
                
                // Use fractional width for the item to ensure solid grid alignment
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
        return 2 // Watchlist + Recommendations
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return watchlistData.count }
        else { return recommendationsData.count }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            
        // ⭐️ DEQUEUE NEW CELL
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: UpcomingBirdGridCollectionViewCell.identifier,
            for: indexPath
        ) as? UpcomingBirdGridCollectionViewCell else {
            return UICollectionViewCell()
        }

        let item = (indexPath.section == 0) ? watchlistData[indexPath.row] : recommendationsData[indexPath.row]
        
        // ⭐️ CONFIGURE
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

extension AllUpcomingBirdsViewController: UICollectionViewDelegate { }
