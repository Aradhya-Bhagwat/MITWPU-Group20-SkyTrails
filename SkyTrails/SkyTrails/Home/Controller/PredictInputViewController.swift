//
//  PredictInputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit
import CoreLocation

class PredictInputViewController: UIViewController, SearchLocationDelegate {
    var inputData: [PredictionInputData] = [PredictionInputData()]
	
    private var cardWidth: CGFloat = 0
	private let spacing: CGFloat = 16.0
	private let sideMargin: CGFloat = 24.0
	
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()
		
		collectionView.register(
			UINib(nibName: PredictionInputCellCollectionViewCell.identifier, bundle: nil),
			forCellWithReuseIdentifier: PredictionInputCellCollectionViewCell.identifier
		)
		collectionView.dataSource = self
		collectionView.delegate = self
		collectionView.setCollectionViewLayout(generateLayout(), animated: false)
        setupPageControl()
        validateInputs()
        applyHeightConstraint()
    }
    
    private func applyHeightConstraint() {
    
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            let neededHeight: CGFloat = 420
            let heightConstraint = collectionView.heightAnchor.constraint(equalToConstant: neededHeight)
            heightConstraint.isActive = true
            
        }
	func generateLayout() -> UICollectionViewLayout {
		return UICollectionViewCompositionalLayout { [weak self] sectionIndex, env -> NSCollectionLayoutSection? in
			guard let self = self else { return nil }
			let itemSize = NSCollectionLayoutSize(
				widthDimension: .fractionalWidth(1.0),
				heightDimension: .fractionalHeight(1.0)
			)
			let item = NSCollectionLayoutItem(layoutSize: itemSize)
			let containerWidth = env.container.contentSize.width
			let groupWidth = containerWidth > 48 ? containerWidth - 48 : containerWidth
			
			let groupSize = NSCollectionLayoutSize(
				widthDimension: .absolute(groupWidth),
				heightDimension: .fractionalHeight(1.0)
			)
			let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
			let section = NSCollectionLayoutSection(group: group)
			section.orthogonalScrollingBehavior = .groupPagingCentered
			section.interGroupSpacing = 16
			section.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
			section.visibleItemsInvalidationHandler = { visibleItems, point, environment in
				let centerX = point.x + environment.container.contentSize.width / 2
				
				let closestIndex = visibleItems
					.min(by: { abs($0.frame.midX - centerX) < abs($1.frame.midX - centerX) })?
					.indexPath.item ?? 0
				
				if self.pageControl.currentPage != closestIndex {
					self.pageControl.currentPage = closestIndex
				}
			}
			
			return section
		}
	}
    private func setupPageControl() {
            pageControl.numberOfPages = inputData.count
            pageControl.currentPage = 0
            pageControl.hidesForSinglePage = true
            pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        }
    
        func didSelectLocation(name: String, lat: Double, lon: Double, forIndex index: Int) {
            guard index < inputData.count else { return }
            
            inputData[index].locationName = name
            inputData[index].latitude = lat
            inputData[index].longitude = lon
            
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.reloadItems(at: [indexPath])
            
            validateInputs()
            
            if let mapVC = self.navigationController?.parent as? PredictMapViewController {
                mapVC.updateMapWithCurrentInputs(inputs: inputData)
            }
        }

        @IBAction func didTapAdd(_ sender: Any) {
            guard inputData.count < 5 else { return }
            inputData.append(PredictionInputData())
            let newIndexPath = IndexPath(item: inputData.count - 1, section: 0)
            collectionView.insertItems(at: [newIndexPath])
            collectionView.scrollToItem(at: newIndexPath, at: .centeredHorizontally, animated: true)
            validateInputs()
        }
        
        @IBAction func didTapDone(_ sender: Any) {

                var allResults: [FinalPredictionResult] = []
                
                for (index, input) in inputData.enumerated() {

                    let resultsForCard = HomeManager.shared.predictBirds(for: input, inputIndex: index)
                    allResults.append(contentsOf: resultsForCard)
                }
                

                let uniqueResults = Array(Set(allResults))
                
                if let parentVC = self.navigationController?.parent as? PredictMapViewController {
                    parentVC.navigateToOutput(
                        inputs: inputData,
                        predictions: uniqueResults
                    )
                }
            }
    @objc func pageControlChanged(_ sender: UIPageControl) {
            let indexPath = IndexPath(item: sender.currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
        
        // MARK: - Logic
        func validateInputs() {
            let allValid = inputData.allSatisfy { $0.locationName != nil }
            doneButton.isEnabled = allValid
        }
        
    func deleteInput(at index: Int) {
            guard inputData.count > 1 else { return }
            
            inputData.remove(at: index)
            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            pageControl.numberOfPages = inputData.count
            pageControl.currentPage = min(pageControl.currentPage, inputData.count - 1)
            collectionView.reloadData()
            validateInputs()
        }
    }

    extension PredictInputViewController: UICollectionViewDataSource, UICollectionViewDelegate {
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return inputData.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PredictionInputCellCollectionViewCell.identifier, for: indexPath) as? PredictionInputCellCollectionViewCell else {
                return UICollectionViewCell()
            }
            
            let data = inputData[indexPath.row]
            
            cell.configure(data: data, index: indexPath.row)
            cell.onSearchTap = { [weak self] in
                guard let self = self else { return }
                let storyboard = UIStoryboard(name: "Home", bundle: nil)
                if let nav = storyboard.instantiateViewController(withIdentifier: "SearchNavigationController") as? UINavigationController,
                   let searchVC = nav.viewControllers.first as? SearchLocationViewController {
                    
                    searchVC.delegate = self
                    searchVC.cellIndex = indexPath.row
                    
                    self.present(nav, animated: true)
                }
            }
            
            cell.onStartDateChange = { [weak self] date in
                self?.inputData[indexPath.row].startDate = date
            }
            
            cell.onEndDateChange = { [weak self] date in
                self?.inputData[indexPath.row].endDate = date
            }
            
            cell.onAreaChange = { [weak self] newVal in
                self?.inputData[indexPath.row].areaValue = newVal
            }
             
            cell.onDelete = { [weak self] in
                    guard let self = self,
                          let currentPath = collectionView.indexPath(for: cell) else { return }
                    self.deleteInput(at: currentPath.item)
                }
            return cell
        }
    }

