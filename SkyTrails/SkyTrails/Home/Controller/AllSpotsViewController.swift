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
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "All Spots"
        self.view.backgroundColor = .systemBackground
        setupNavigationBar()
        setupCollectionView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Clear the cache so the layout recalculates for the new width
        self.cachedItemSize = nil
        
        coordinator.animate(alongsideTransition: { _ in
            // Invalidate the layout to trigger cell resizing
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
    
    
    private func setupCollectionView() {

        collectionView.collectionViewLayout = createLayout()
        

        collectionView.register(
            UINib(nibName: GridSpotsToVisitCollectionViewCell.identifier, bundle: nil),
            forCellWithReuseIdentifier: GridSpotsToVisitCollectionViewCell.identifier
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

        let predictButton = UIBarButtonItem(title: "Predict", style: .plain, target: self, action: #selector(didTapPredict))
        self.navigationItem.rightBarButtonItem = predictButton
    }
        
    @objc private func didTapPredict() {
        self.performSegue(withIdentifier: "ShowPredictMap", sender: self)

    }
    

    private func createLayout() -> UICollectionViewLayout {
            return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
                guard let self = self else { return nil }
                
                let containerWidth = layoutEnvironment.container.effectiveContentSize.width

                if self.cachedItemSize == nil {

                    let screenBounds = self.view.window?.windowScene?.screen.bounds ?? self.view.bounds
                    let screenMinDimension = min(screenBounds.width, screenBounds.height)
                    let spacing: CGFloat = 16.0
                    let maxCardWidth: CGFloat = 300.0
                    let minColumns = 2
                    
                    var columnCount = minColumns
                    var calculatedWidth = (screenMinDimension - (spacing * CGFloat(columnCount - 1)) - 16) / CGFloat(columnCount)
                    
                    while calculatedWidth > maxCardWidth {
                        columnCount += 1
                        calculatedWidth = (screenMinDimension - (spacing * CGFloat(columnCount - 1)) - 16) / CGFloat(columnCount)
                    }
                    
                    let heightMultiplier: CGFloat = 195.0 / 176.0
                    let calculatedHeight = calculatedWidth * heightMultiplier
                    
                    // Store this "ideal" size
                    self.cachedItemSize = NSCollectionLayoutSize(
                        widthDimension: .absolute(calculatedWidth),
                        heightDimension: .absolute(calculatedHeight)
                    )

                }
                
                guard let fixedSize = self.cachedItemSize else { return nil }
                

                let itemWidth = fixedSize.widthDimension.dimension
                let interItemSpacing: CGFloat = 8
                
                // Math: How many (Item + Spacing) fit?
                // Estimate columns
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
                withReuseIdentifier: GridSpotsToVisitCollectionViewCell.identifier,
                for: indexPath
            ) as? GridSpotsToVisitCollectionViewCell else {
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

            
            // 1. Prepare Data for Prediction Map
            guard let lat = item.latitude, let lon = item.longitude else {
                print( "\(item.title)")
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
                
                predictMapVC.loadViewIfNeeded()
                
                // Execute the navigation to the bottom sheet output
                predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
            }
        }
    }
