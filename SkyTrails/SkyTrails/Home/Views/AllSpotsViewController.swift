//
//  AllSpotsViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class AllSpotsViewController: UIViewController {
    
    var watchlistData: [PopularSpot] = []
    var recommendationsData: [PopularSpot] = []
    
    private var cachedItemSize: NSCollectionLayoutSize?
    
    // MARK: - UI Elements
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "All Spots"
        self.view.backgroundColor = .systemBackground
        setupNavigationBar()
        setupCollectionView()
    }
    
    
    // MARK: - 2. Setup Collection View
    private func setupCollectionView() {
        // Initialize with Compositional Layout
        collectionView.collectionViewLayout = createLayout()
        
        // Register Cell
        collectionView.register(
            UINib(nibName: SpotsToVisitCollectionViewCell.identifier, bundle: nil),
            forCellWithReuseIdentifier: SpotsToVisitCollectionViewCell.identifier
        )
        
        // Register Header
        collectionView.register(
            UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderCollectionReusableView.identifier
        )
        
        // Set Delegates
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    private func setupNavigationBar() {
        // Add "Predict" button to Top Right
        let predictButton = UIBarButtonItem(title: "Predict", style: .plain, target: self, action: #selector(didTapPredict))
        self.navigationItem.rightBarButtonItem = predictButton
    }
        
    @objc private func didTapPredict() {
        self.performSegue(withIdentifier: "ShowPredictMap", sender: self)
        print("Predict button tapped! (Navigate to Prediction Page later)")
        // TODO: Navigation to Prediction Page goes here
    }
    
    // MARK: - 3. Dynamic Ratio Layout Logic
    // MARK: - 3. Smart Grid Layout (Fixed Size per Device)
    private func createLayout() -> UICollectionViewLayout {
            return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
                guard let self = self else { return nil }
                
                // Current available width of the screen
                let containerWidth = layoutEnvironment.container.effectiveContentSize.width
                
                // 1. Calculate the Fixed Card Size (Only once!)
                // We base this on the screen's "Portrait" width (narrowest dimension) to ensure consistency.
                if self.cachedItemSize == nil {
                    
                    // Use the smallest dimension of the screen to calculate the "Base" layout
                    // This simulates "Portrait" width even if we launched in Landscape.
                    let screenMinDimension = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
                    
                    // Logic: Fit at least 2 columns in that min dimension, max width 400
                    let padding: CGFloat = 16.0 // Total padding (8 left + 8 right)
                    let spacing: CGFloat = 16.0 // Inter-item spacing
                    
                    let maxCardWidth: CGFloat = 400.0
                    let minColumns = 2
                    
                    var columnCount = minColumns
                    
                    // Calculate width per item excluding spacing
                    // Available Space = ScreenWidth - (Spacing * (Columns - 1)) - OuterPadding
                    // ItemWidth = AvailableSpace / Columns
                    
                    // Simplified calculation for sizing:
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
                    print("🔒 Fixed Card Size Calculated: \(calculatedWidth) x \(calculatedHeight)")
                }
                
                // 2. Use Fixed Size to Layout Current Screen
                guard let fixedSize = self.cachedItemSize else { return nil }
                
                // Determine how many of these "Fixed Cards" fit in the CURRENT width
                // (In Landscape, containerWidth is huge, so more columns will fit)
                let itemWidth = fixedSize.widthDimension.dimension
                let interItemSpacing: CGFloat = 8
                
                // Math: How many (Item + Spacing) fit?
                // Estimate columns
                let estimatedColumns = Int((containerWidth + interItemSpacing) / (itemWidth + interItemSpacing))
                let actualColumns = max(1, estimatedColumns) // Ensure at least 1 column
                
                // 3. Build Layout Group
                
                // We use a "fractional" approach for the group to ensure the grid is solid
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
    extension AllSpotsViewController: UICollectionViewDataSource {
        
        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 2 // Watchlist + Recommendations
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            if section == 0 {
                return watchlistData.count
            } else {
                return recommendationsData.count
            }
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
                
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: SpotsToVisitCollectionViewCell.identifier,
                for: indexPath
            ) as? SpotsToVisitCollectionViewCell else {
                return UICollectionViewCell()
            }

            let item = (indexPath.section == 0) ? watchlistData[indexPath.row] : recommendationsData[indexPath.row]
            
            cell.configure(with: item)
            
            return cell
        }
        
        // Headers
        func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            guard kind == UICollectionView.elementKindSectionHeader,
                  let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier, for: indexPath) as? SectionHeaderCollectionReusableView else {
                return UICollectionReusableView()
            }
            
            if indexPath.section == 0 {
                header.isHidden = watchlistData.isEmpty
                header.configure(title: "Your Watchlist")
            } else {
                header.isHidden = false
                header.configure(title: "Recommendations")
            }
            return header
        }
    }

    // MARK: - Delegate
    extension AllSpotsViewController: UICollectionViewDelegate {
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let item: PopularSpot
            if indexPath.section == 0 {
                item = watchlistData[indexPath.row]
            } else {
                item = recommendationsData[indexPath.row]
            }
            print("Spot card clicked: \(item.title) at section \(indexPath.section), row \(indexPath.row)")
            
            // 1. Prepare Data for Prediction Map
            guard let lat = item.latitude, let lon = item.longitude else {
                print(" Missing coordinates for spot: \(item.title)")
                return
            }
            
            // Create Input Data (The Spot itself)
            var inputData = PredictionInputData()
            inputData.locationName = item.title
            inputData.latitude = lat
            inputData.longitude = lon
            inputData.areaValue = Int(item.radius ?? 5.0)
            inputData.startDate = Date()
            inputData.endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
            
            // Create Prediction Results (The Birds at that spot)
            let predictions: [FinalPredictionResult] = (item.birds ?? []).map { bird in
                return FinalPredictionResult(
                    birdName: bird.name,
                    imageName: bird.imageName,
                    matchedInputIndex: 0, // All match this single input
                    matchedLocation: (lat: bird.lat, lon: bird.lon)
                )
            }
            
            // 2. Instantiate and Navigate
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
                
                // Push to the map view
                self.navigationController?.pushViewController(predictMapVC, animated: true)
                
                // 3. Immediately transition to the Output state (bypass input wizard)
                // We need the view to load first so the map and modal container are set up
                predictMapVC.loadViewIfNeeded()
                
                // Execute the navigation to the bottom sheet output
                predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
            }
        }
    }
