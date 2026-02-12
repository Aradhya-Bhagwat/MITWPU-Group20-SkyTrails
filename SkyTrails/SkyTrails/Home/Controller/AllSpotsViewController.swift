//
//  AllSpotsViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class AllSpotsViewController: UIViewController {
    
    var watchlistData: [PopularSpotResult] = []
    var recommendationsData: [PopularSpotResult] = []
    private var cachedItemSize: NSCollectionLayoutSize?
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "All Spots"
        setupTraitChangeHandling()
        applySemanticAppearance()
        setupNavigationBar()
        setupCollectionView()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
        collectionView.reloadData()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
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
        collectionView.backgroundColor = .clear
    }

    private func applySemanticAppearance() {
        view.backgroundColor = .systemBackground
        collectionView?.backgroundColor = .clear
    }
    
    private func setupNavigationBar() {
        let predictSpot = UIImage(named: "upcomingspots")
        let predictButton = UIBarButtonItem(image: predictSpot, style: .plain, target: self, action: #selector(didTapPredict))
        predictButton.tintColor = .systemBlue
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
                
                let heightMultiplier: CGFloat = 195.0 / 176.0
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

extension AllSpotsViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (section == 0) ? watchlistData.count : recommendationsData.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GridSpotsToVisitCollectionViewCell.identifier,
            for: indexPath
        ) as? GridSpotsToVisitCollectionViewCell else {
            return UICollectionViewCell()
        }

        let item = (indexPath.section == 0) ? watchlistData[indexPath.row] : recommendationsData[indexPath.row]
        
        // 💡 FETCH DYNAMIC DATA: Get the pre-calculated count from HomeManager
        let activeCount = HomeManager.shared.spotSpeciesCountCache[item.title] ?? 0
        
        // 💡 CONFIGURE WITH INT: Ensure your Grid cell's configure method accepts Int
        cell.configure(
            image: UIImage(named: item.imageName ?? "default_spot"),
            title: item.title,
            speciesCount: activeCount
        )
        
        return cell
    }
    
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

extension AllSpotsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = (indexPath.section == 0) ? watchlistData[indexPath.row] : recommendationsData[indexPath.row]

        let lat = item.latitude
        let lon = item.longitude
        
        // 1. Prepare search criteria
        var inputData = PredictionInputData()
        inputData.locationName = item.title
        inputData.latitude = lat
        inputData.longitude = lon
        inputData.areaValue = Int(item.radius)
        inputData.startDate = Date()
        // Match the live-week logic by setting a 1-week window
        inputData.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        
        // 2. 💡 LIVE PREDICTION: Perform the dynamic search against global speciesData
        let predictions = HomeManager.shared.getLivePredictions(
            for: lat,
            lon: lon,
            radiusKm: item.radius
        )
        
        // 3. Navigate to Output
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
            self.navigationController?.pushViewController(predictMapVC, animated: true)
            predictMapVC.loadViewIfNeeded()
            predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
        }
    }
}
