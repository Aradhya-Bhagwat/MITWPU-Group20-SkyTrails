//
//  PredictInputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit

class PredictInputViewController: UIViewController {
    var inputData: [PredictionInputData] = [PredictionInputData()]
    private var cardWidth: CGFloat = 0
        private let spacing: CGFloat = 16.0
        private let sideMargin: CGFloat = 24.0
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Temporary Test Code in PredictInputViewController.swift
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let testVC = storyboard.instantiateViewController(withIdentifier: "PredictOutputViewController")
        print("Test Instantiation Result: \(testVC)")
        // The line above should print "PredictOutputViewController" if it's found.
       
        setupPageControl()
        setupCollectionView()
        validateInputs()
        applyHeightConstraint()
        // Do any additional setup after loading the view.
    }
    
    private func applyHeightConstraint() {
            // 1. Disable the auto-resizing mask translation
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            
            // 2. Calculate needed height: Card Height (320) + Shadow/Padding (40)
            let neededHeight: CGFloat = 360
            
            // 3. Add a hard height constraint
            let heightConstraint = collectionView.heightAnchor.constraint(equalToConstant: neededHeight)
            heightConstraint.isActive = true
            
            // Note: If you have a 'Bottom' constraint in Storyboard connecting the
            // CollectionView to the bottom of the screen, you might get a constraint warning.
            // If so, you should lower the priority of that storyboard constraint or remove it.
        }
    private func setupCollectionView() {
            // ⭐️ USE CUSTOM LAYOUT
            let layout = CardSnappingLayout() // <--- Change this line
            
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 16
            layout.sectionInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
            
            let screenWidth = UIScreen.main.bounds.width
            layout.itemSize = CGSize(width: screenWidth - 48, height: 320)
            
            collectionView.collectionViewLayout = layout
            
            // ⭐️ CRITICAL SETTINGS FOR SNAPPING
        collectionView.isPagingEnabled = false
                collectionView.decelerationRate = .fast
                collectionView.showsHorizontalScrollIndicator = false // Hide the bar for cleaner look
                collectionView.backgroundColor = .clear
            
            // Register Cell
            collectionView.register(
                UINib(nibName: PredictionInputCellCollectionViewCell.identifier, bundle: nil),
                forCellWithReuseIdentifier: PredictionInputCellCollectionViewCell.identifier
            )
            
            collectionView.dataSource = self
            collectionView.delegate = self
        }
    private func setupPageControl() {
            pageControl.numberOfPages = inputData.count
            pageControl.currentPage = 0
            pageControl.hidesForSinglePage = true
            // Add target for tap interaction (optional)
            pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        }

        // MARK: - Navigation Actions
        
        @IBAction func didTapAdd(_ sender: Any) {
            // Limit to 5 inputs
            guard inputData.count < 5 else { return }
            
            // Add new empty data model
            inputData.append(PredictionInputData())
            
            // Update Collection View
            let newIndexPath = IndexPath(item: inputData.count - 1, section: 0)
            collectionView.insertItems(at: [newIndexPath])
            
            // Scroll to the new card
            collectionView.scrollToItem(at: newIndexPath, at: .centeredHorizontally, animated: true)
            
            validateInputs()
        }
        
        @IBAction func didTapDone(_ sender: Any) {
            print("✅ STARTING PREDICTION FOR \(inputData.count) LOCATIONS...")
                
                // 1. Process all inputs using the Prediction Engine
                var allResults: [FinalPredictionResult] = []
                
                for (index, input) in inputData.enumerated() {
                    // Use the PredictionEngine to find birds for this card's criteria
                    let resultsForCard = PredictionEngine.shared.predictBirds(for: input, inputIndex: index)
                    allResults.append(contentsOf: resultsForCard)
                }
                
                // 2. Filter to unique birds (in case one bird is predicted by multiple cards)
                // We use the Hashable conformance implemented in models.swift
                let uniqueResults = Array(Set(allResults))
                
                if let parentVC = self.navigationController?.parent as? PredictMapViewController {
                    // Pass both the original input data (for map circles/labels) and the final predictions
                    parentVC.navigateToOutput(
                        inputs: inputData,
                        predictions: uniqueResults
                    )
                }
            }
    @objc func pageControlChanged(_ sender: UIPageControl) {
            // Allow user to tap dots to scroll
            let indexPath = IndexPath(item: sender.currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    
    // MARK: - Page Control Helper (Geometry Based)
    // MARK: - Page Control Helper (Math Based)
        private func updatePageControl(forceIndex: Int? = nil) {
            pageControl.numberOfPages = inputData.count
            
            // 1. If we forced an index (like when adding/deleting), use it immediately
            if let index = forceIndex {
                pageControl.currentPage = index
                return
            }
            
            // 2. Dynamic Math Calculation
            // Get the layout to ensure we have the real numbers
            guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
            
            let itemWidth = layout.itemSize.width
            let spacing = layout.minimumLineSpacing
            let stride = itemWidth + spacing
            
            // Use current scroll offset to find the decimal page index
            let offset = collectionView.contentOffset.x
            
            // Logic: Offset 0 = Index 0. Offset 'Stride' = Index 1.
            // We round to the nearest whole number to "snap" the dot.
            let index = Int(round(offset / stride))
            
            // 3. Safety Clamp (Prevent crashes or invalid dots)
            // Ensure we don't go below 0 or above the last index
            let safeIndex = max(0, min(index, inputData.count - 1))
            
            if pageControl.currentPage != safeIndex {
                pageControl.currentPage = safeIndex
            }
        }
        
        // MARK: - Logic
        func validateInputs() {
            // Button enabled ONLY if ALL cards have a Location selected
            let allValid = inputData.allSatisfy { $0.locationName != nil }
            doneButton.isEnabled = allValid
        }
        
    func deleteInput(at index: Int) {
            guard inputData.count > 1 else { return }
            
            inputData.remove(at: index)
            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            
            // ⭐️ Update Page Control
            pageControl.numberOfPages = inputData.count
            // Ensure current page is valid
            pageControl.currentPage = min(pageControl.currentPage, inputData.count - 1)
            
            collectionView.reloadData()
            validateInputs()
        }
    
//    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//            let width = scrollView.frame.width
//        let currentPage = Int(round(scrollView.contentOffset.x / width))
//            
//            self.pageControl.currentPage = currentPage
//    
//        }
        
        // MARK: - Modal Presenters
        
        func openSearchModal(forIndex index: Int) {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            
            // Wrap in Nav Controller for the header bar
            guard let navVC = storyboard.instantiateViewController(withIdentifier: "SearchNavigationController") as? UINavigationController,
                  let searchVC = navVC.viewControllers.first as? SearchLocationViewController else {
                return
            }
            
            searchVC.delegate = self
            searchVC.cellIndex = index
            navVC.modalPresentationStyle = .fullScreen // Full focus
            
            self.present(navVC, animated: true)
        }
        
        func openDatePicker(forIndex index: Int, isStartDate: Bool) {
            // Simple Alert with DatePicker for MVP
            let alert = UIAlertController(title: isStartDate ? "Select Start Date" : "Select End Date", message: nil, preferredStyle: .actionSheet)
            
            let datePicker = UIDatePicker()
            datePicker.datePickerMode = .date
            datePicker.preferredDatePickerStyle = .wheels
            datePicker.frame = CGRect(x: 0, y: 50, width: alert.view.bounds.width - 20, height: 200)
            
            alert.view.heightAnchor.constraint(equalToConstant: 300).isActive = true
            alert.view.addSubview(datePicker)
            
            let selectAction = UIAlertAction(title: "Select", style: .default) { [weak self] _ in
                guard let self = self else { return }
                let date = datePicker.date
                
                if isStartDate {
                    self.inputData[index].startDate = date
                } else {
                    self.inputData[index].endDate = date
                }
                self.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            alert.addAction(selectAction)
            alert.addAction(cancelAction)
            
            self.present(alert, animated: true)
        }
    }

    // MARK: - Collection View DataSource
    extension PredictInputViewController: UICollectionViewDataSource, UICollectionViewDelegate {
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return inputData.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PredictionInputCellCollectionViewCell.identifier, for: indexPath) as? PredictionInputCellCollectionViewCell else {
                return UICollectionViewCell()
            }
            
            let data = inputData[indexPath.row]
            
            // 1. Configure UI
            cell.configure(data: data, index: indexPath.row)
            
            // 2. Wire up Search
            cell.onSearchTap = { [weak self] in
                self?.openSearchModal(forIndex: indexPath.row)
            }
            
            // 3. Wire up Dates
            cell.onStartDateTap = { [weak self] in
                self?.openDatePicker(forIndex: indexPath.row, isStartDate: true)
            }
            
            cell.onEndDateTap = { [weak self] in
                self?.openDatePicker(forIndex: indexPath.row, isStartDate: false)
            }
            
            // 4. Wire up Area
            cell.onAreaChange = { [weak self] newVal in
                self?.inputData[indexPath.row].areaValue = newVal
            }
            
            // 5. Wire up Delete
            cell.onDelete = { [weak self] in
                    // 1. Ask the collection view: "Where is this cell RIGHT NOW?"
                    guard let self = self,
                          let currentPath = collectionView.indexPath(for: cell) else { return }
                    
                    // 2. Pass the FRESH index to your delete function
                    self.deleteInput(at: currentPath.item)
                }
            return cell
        }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
                updatePageControl()
            }
    }

    // MARK: - Search Delegate
    extension PredictInputViewController: SearchLocationDelegate {
        func didSelectLocation(name: String, lat: Double, lon: Double, forIndex index: Int) {
            print("📍 Received Location: \(name) for card \(index)")
            
            inputData[index].locationName = name
            inputData[index].latitude = lat
            inputData[index].longitude = lon
            
            // Reload cell to show new name
            collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            
            validateInputs() // Enable "Done" button if all valid
        }
    }

// MARK: - Custom Snapping Layout
class CardSnappingLayout: UICollectionViewFlowLayout {
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        
        guard let collectionView = collectionView else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        
        // 1. Calculate the center of the "proposed" landing spot
        let targetRect = CGRect(x: proposedContentOffset.x, y: 0, width: collectionView.bounds.width, height: collectionView.bounds.height)
        let horizontalCenter = proposedContentOffset.x + (collectionView.bounds.width / 2.0)
        
        // 2. Find the cell closest to that center
        var offsetAdjustment = CGFloat.greatestFiniteMagnitude
        
        // Inspect all visible attributes in the target area
        guard let attributesList = super.layoutAttributesForElements(in: targetRect) else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        
        for layoutAttributes in attributesList {
            let itemHorizontalCenter = layoutAttributes.center.x
            
            // Find distance from the center
            if abs(itemHorizontalCenter - horizontalCenter) < abs(offsetAdjustment) {
                offsetAdjustment = itemHorizontalCenter - horizontalCenter
            }
        }
        
        // 3. Snap to that item's center
        return CGPoint(x: proposedContentOffset.x + offsetAdjustment, y: proposedContentOffset.y)
    }
}
