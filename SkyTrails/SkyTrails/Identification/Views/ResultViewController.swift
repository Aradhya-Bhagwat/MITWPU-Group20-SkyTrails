	//
	//  ResultViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 28/11/25.
	//

import UIKit

class ResultViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ResultCellDelegate {
	
	@IBOutlet weak var tableContainerView: UIView!
	@IBOutlet weak var resultTableView: UITableView!
	
	var viewModel: ViewModel!
	weak var delegate: IdentificationFlowStepDelegate?
	
		// History editing state
	var historyItem: History?
	var historyIndex: Int?
	
		// UPDATED: Now uses the new IdentificationBird model
	var selectedResult: IdentificationBird?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		resultTableView.register(
			UINib(nibName: "ResultTableViewCell", bundle: nil),
			forCellReuseIdentifier: "ResultTableViewCell"
		)
		resultTableView.rowHeight = 75
		resultTableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
		
		resultTableView.delegate = self
		resultTableView.dataSource = self
		
		styleTableContainer()
		setupLeftResetButton()
		setupRightTickButton()
		
			// MARK: - 1. Bind to ViewModel Updates
			// This ensures the table reloads whenever the filter finishes
		viewModel.onResultsUpdated = { [weak self] in
			DispatchQueue.main.async {
				self?.resultTableView.reloadData()
			}
		}
		
			// MARK: - 2. Initial Setup
			// If editing history, pre-select the bird
		if let history = historyItem {
			// Find the bird in the FULL database first, not just filtered results
			if let match = viewModel.birdResults.first(where: { $0.name == history.specieName }) {
				selectedResult = match
            } else if let dbBird = viewModel.getBird(byName: history.specieName) {
                // Manually construct result if not in current filter
                selectedResult = IdentificationBird(
                    id: dbBird.id,
                    name: dbBird.commonName,
                    scientificName: dbBird.scientificName ?? "",
                    confidence: 1.0, // Historical item is 100% matched effectively
                    description: "From History",
                    imageName: dbBird.imageName,
                    scoreBreakdown: "From History"
                )
                // Append to results so table shows it
                viewModel.birdResults = [selectedResult!]
            }
		} else {
				// If not editing history, run the filter once to ensure data is fresh
			viewModel.filterBirds(
				shape: viewModel.selectedShapeId,
				size: viewModel.selectedSizeCategory,
				location: viewModel.selectedLocation,
				fieldMarks: viewModel.selectedFieldMarks
			)
		}
	}
	
		// MARK: - UI Configuration
	
	func styleTableContainer() {
		tableContainerView.backgroundColor = .white
		tableContainerView.layer.cornerRadius = 12
		tableContainerView.layer.shadowColor = UIColor.black.cgColor
		tableContainerView.layer.shadowOpacity = 0.1
		tableContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
		tableContainerView.layer.shadowRadius = 8
		tableContainerView.layer.masksToBounds = false
	}
	
	private func setupRightTickButton() {
		let button = UIButton(type: .system)
		button.backgroundColor = .white
		button.layer.cornerRadius = 20
		button.layer.masksToBounds = true
		
		let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
		let image = UIImage(systemName: "checkmark", withConfiguration: config)
		button.setImage(image, for: .normal)
		button.tintColor = .black
		button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
		
		button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
		navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
	}
	
	private func setupLeftResetButton() {
		let button = UIButton(type: .system)
		button.backgroundColor = .white
		button.layer.cornerRadius = 20
		button.layer.masksToBounds = true
		
		let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
		let image = UIImage(systemName: "arrow.trianglehead.counterclockwise", withConfiguration: config)
		button.setImage(image, for: .normal)
		button.tintColor = .black
		button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
		
		button.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)
		navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
	}
	
		// MARK: - Actions
	
	@objc private func nextTapped() {
		guard let result = selectedResult else {
							navigationController?.popToRootViewController(animated: true)
			return
		}
		
			// Create the History Entry
		let entry = History(
			imageView: result.imageName,
			specieName: result.name,
			date: today()
		)
		
			// FLOW B: If editing existing history -> replace
		if let index = historyIndex {
			viewModel.histories[index] = entry
		}
			// FLOW A: Normal case -> add new history
		else {
			viewModel.addToHistory(entry)
		}
		
		navigationController?.popToRootViewController(animated: true)
		delegate?.didFinishStep()
	}
	
	@objc private func restartTapped() {
		delegate?.didTapLeftButton()
	}
	
	func today() -> String {
		let f = DateFormatter()
		f.dateFormat = "yyyy-MM-dd"
		return f.string(from: Date())
	}
	
		// MARK: - TableView Data Source
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.birdResults.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ResultTableViewCell", for: indexPath) as! ResultTableViewCell
		
		let result = viewModel.birdResults[indexPath.row]
		let img = UIImage(named: result.imageName) // Using new imageName property
		
			// Format confidence: 0.95 -> "95"
		let percentString = String(Int(result.confidence * 100))
		
		cell.configure(
			image: img,
			name: result.name,
			percentage: percentString
		)
		
			// Highlight selection
		if selectedResult?.name == result.name {
			cell.backgroundColor = UIColor.systemGray5
		} else {
			cell.backgroundColor = .white
		}
		
		cell.delegate = self
		return cell
	}
	
		// MARK: - TableView Delegate
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
			// Update selection
		selectedResult = viewModel.birdResults[indexPath.row]
		tableView.reloadData() // Refresh to show grey background on selected row
	}
	
		// MARK: - ResultCellDelegate
	
	func didTapPredict(for cell: ResultTableViewCell) {
		print("Predict species on map tapped")
			// Implementation for map prediction can go here
	}
	
	func didTapAddToWatchlist(for cell: ResultTableViewCell) {
		guard let indexPath = resultTableView.indexPath(for: cell) else { return }
		let bird = viewModel.birdResults[indexPath.row]
		
			// Logic to add to watchlist
            // 1. Convert to SavedBird (Bird model)
		let savedBird = bird.toSavedBird(location: viewModel.selectedLocation)
        
            // 2. Add to "My Watchlist" (Default)
        saveToWatchlist(bird: savedBird)
	}
    
    private func saveToWatchlist(bird: Bird) {
        // Use WatchlistManager shared instance
        let manager = WatchlistManager.shared
        
        // Find "My Watchlist" (assuming it's the first one or finding by title)
        if let defaultWatchlist = manager.watchlists.first {
            // Add to "To Observe" list by default
            manager.addBirds([bird], to: defaultWatchlist.id, asObserved: false)
            
            // Show Alert
            let alert = UIAlertController(
                title: "Added to watchlist",
                message: "\(bird.name) added to My watchlist under to observe",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
             print("❌ No default watchlist found to save to.")
        }
    }
}
