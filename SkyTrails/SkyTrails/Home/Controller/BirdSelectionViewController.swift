//
//  BirdSelectionViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class BirdSelectionViewController: UIViewController {

    var allSpecies: [SpeciesData] = []
    var filteredSpecies: [SpeciesData] = []
    var selectedSpecies: Set<String> = []
    var existingInputs: [BirdDateInput] = []
    

    private var cachedItemSize: NSCollectionLayoutSize?
    
    @IBOutlet weak var searchCollection: UICollectionView!
    @IBOutlet weak var SearchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.selectedSpecies = Set(existingInputs.map { $0.species.id })
        self.title = "Select Species"
        
        setupNavigationBar()
        setupCollectionView()
        
        SearchBar.delegate = self
        SearchBar.placeholder = "Search"
        SearchBar.searchBarStyle = .minimal
        SearchBar.backgroundColor = .systemBackground

        if let speciesData = HomeManager.shared.predictionData?.speciesData {
            self.allSpecies = speciesData.sorted { $0.name < $1.name }
            self.filteredSpecies = allSpecies
        }
    }
    
    private func setupNavigationBar() {
        let nextButton = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(didTapNext))
        navigationItem.rightBarButtonItem = nextButton
    }
    
    private func setupCollectionView() {
        searchCollection.collectionViewLayout = createLayout()
        searchCollection.backgroundColor = .systemBackground
        
        // Register Cell
        searchCollection.register(
            UINib(nibName: "GridUpcomingBirdCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: GridUpcomingGridCollectionViewCell.identifier
        )
        
        searchCollection.dataSource = self
        searchCollection.delegate = self
    }
    
    // Layout logic from AllUpcomingBirdsViewController
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
                heightDimension: .estimated(groupHeight)
            )
            
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 24, trailing: 8)
            
            return section
        }
    }
    
    @objc private func didTapNext() {

        let selectedObjects = allSpecies.filter { selectedSpecies.contains($0.id) }
        guard !selectedObjects.isEmpty else {
            let alert = UIAlertController(title: "No Selection", message: "Please select at least one bird.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        

        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        guard let dateInputVC = storyboard.instantiateViewController(withIdentifier: "BirdDateInputViewController") as? BirdDateInputViewController else { return }
        
        dateInputVC.speciesList = selectedObjects
        dateInputVC.currentIndex = 0
        
        var newCollectedData: [BirdDateInput] = []
        for species in selectedObjects {
            if let existing = existingInputs.first(where: { $0.species.id == species.id }) {
                newCollectedData.append(existing)
            } else {
                let start = Date()
                let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
                newCollectedData.append(BirdDateInput(species: species, startDate: start, endDate: end))
            }
        }
        dateInputVC.collectedData = newCollectedData
        
        navigationController?.pushViewController(dateInputVC, animated: true)
    }
}

extension BirdSelectionViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredSpecies = allSpecies
        } else {
            filteredSpecies = allSpecies.filter { species in
                let name = species.name.lowercased()
                let query = searchText.lowercased()
                
                return name.hasPrefix(query) || name.contains(" \(query)")
            }
        }
        searchCollection.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension BirdSelectionViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredSpecies.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GridUpcomingGridCollectionViewCell.identifier,
            for: indexPath
        ) as? GridUpcomingGridCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let species = filteredSpecies[indexPath.row]
        // Map SpeciesData to UpcomingBird for configuration
        let upcomingBird = UpcomingBird(imageName: species.imageName, title: species.name, date: "")
        cell.configure(with: upcomingBird)
        cell.DateLabel.isHidden = true
        
        // Handle selection state
        if selectedSpecies.contains(species.id) {
            cell.containerView.layer.borderWidth = 3.0
            cell.containerView.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            cell.containerView.layer.borderWidth = 0.0
            cell.containerView.layer.borderColor = UIColor.clear.cgColor
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        searchCollection.deselectItem(at: indexPath, animated: true)
        
        let species = filteredSpecies[indexPath.row]
        if selectedSpecies.contains(species.id) {
            selectedSpecies.remove(species.id)
        } else {
            selectedSpecies.insert(species.id)
        }
        
        searchCollection.reloadItems(at: [indexPath])
    }
}

