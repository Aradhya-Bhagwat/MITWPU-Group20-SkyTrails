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
        
        // MARK: - UI Elements
        private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "All Spots"
        self.view.backgroundColor = .systemBackground
                
        setupNavigationBar()
        setupCollectionView()

        // Do any additional setup after loading the view.
    }
    

    // MARK: - 1. Setup Navigation
        private func setupNavigationBar() {
            // Standard Back button is handled automatically by Navigation Controller.
            
            // Add "Predict" button to Top Right
            let predictButton = UIBarButtonItem(title: "Predict", style: .plain, target: self, action: #selector(didTapPredict))
            predictButton.tintColor = .systemBlue // Or your app color
            self.navigationItem.rightBarButtonItem = predictButton
        }
        
        @objc private func didTapPredict() {
            print("Predict button tapped! (Navigate to Prediction Page later)")
            // TODO: Navigation to Prediction Page goes here
        }

        // MARK: - 2. Setup Collection View
        private func setupCollectionView() {
            // Initialize with Compositional Layout
            collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
            collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            collectionView.backgroundColor = .systemBackground
            
            // Register Cell (Reusing the existing Home Cell)
            collectionView.register(
                UINib(nibName: "q_3SpotsToVisitCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "q_3SpotsToVisitCollectionViewCell"
            )
            
            // Register Header (Reusing the existing Home Header)
            collectionView.register(
                UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil),
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                withReuseIdentifier: SectionHeaderCollectionReusableView.identifier
            )
            
            // Set Delegates
            collectionView.dataSource = self
            collectionView.delegate = self
            
            view.addSubview(collectionView)
        }
        
        // MARK: - 3. Layout Logic (2-Column Grid)
        private func createLayout() -> UICollectionViewLayout {
            return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
                
                // --- Item ---
                // Takes up 50% of the width (2 items per row)
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                // Padding around each card
                item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

                // --- Group ---
                // Full width of screen, fixed height for the row
                // Note: Adjust 'absolute(240)' if your cards need more height
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(240)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                // --- Section ---
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 24, trailing: 8)
                
                // --- Header ---
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(44)
                )
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
            // Section 0: Watchlist
            // Section 1: Recommendations
            return 2
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
                withReuseIdentifier: "q_3SpotsToVisitCollectionViewCell",
                for: indexPath
            ) as? q_3SpotsToVisitCollectionViewCell else {
                return UICollectionViewCell()
            }

            // Determine which array to use
            let item: PopularSpot
            if indexPath.section == 0 {
                item = watchlistData[indexPath.row]
            } else {
                item = recommendationsData[indexPath.row]
            }
            
            // Configure Cell
            cell.configure(
                image: UIImage(named: item.imageName),
                title: item.title,
                date: item.location
            )
            
            return cell
        }
        
        // Headers (Watchlist vs Recommendations)
        func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            
            guard kind == UICollectionView.elementKindSectionHeader,
                  let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: SectionHeaderCollectionReusableView.identifier,
                    for: indexPath
                  ) as? SectionHeaderCollectionReusableView else {
                return UICollectionReusableView()
            }
            
            if indexPath.section == 0 {
                // Hide header if Watchlist is empty (optional, looks cleaner)
                if watchlistData.isEmpty {
                    header.isHidden = true
                } else {
                    header.isHidden = false
                    header.configure(title: "Your Watchlist")
                }
            } else {
                // Section 1
                header.isHidden = false
                header.configure(title: "Recommendations")
            }
            
            return header
        }
    }

    // MARK: - Delegate
    extension AllSpotsViewController: UICollectionViewDelegate {
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            print("Selected spot at section \(indexPath.section), row \(indexPath.row)")
            // Future: Navigate to Spot Detail Page
        }
}
