	//
	//  WatchlistCoordinator.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 24/11/25.
	//

import UIKit

enum WatchlistMode {
	case observed
	case unobserved
	case create
}

class WatchlistCoordinator {
	unowned var navigationController: UINavigationController
	
		// State for the Detail Loop
	private var birdQueue: [Bird] = []
    private var processedBirds: [Bird] = []
	private var currentMode: WatchlistMode = .observed
    
    // Context for Adding
    var targetWatchlistId: UUID?
    weak var viewModel: WatchlistViewModel?
	
	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}
	
	func start() {
			// Entry point logic if needed
	}
	

	
		// Step 2: Screen #3 (Species Selection)
	func showSpeciesSelection(mode: WatchlistMode) {
        let vc = UIStoryboard.named("Watchlist").instantiate(SpeciesSelectionViewController.self)
		
		vc.coordinator = self
		vc.mode = mode
		vc.viewModel = self.viewModel ?? WatchlistViewModel() // Use existing VM if available
		
		navigationController.pushViewController(vc, animated: true)
	}
	
		// Step 3: Start Detail Entry Loop
	func startDetailLoop(birds: [Bird], mode: WatchlistMode) {
		self.birdQueue = birds
        self.processedBirds = []
		self.currentMode = mode
		showNextInLoop()
	}
	

    func saveBirdDetails(bird: Bird) {
        processedBirds.append(bird)
        showNextInLoop()
    }

	
		// Step 4: Create Watchlist
	func showCreateWatchlist(type: WatchlistType, viewModel: WatchlistViewModel?) {
        let vc = UIStoryboard.named("Watchlist").instantiate(EditWatchlistDetailViewController.self)
        
        vc.watchlistType = type
        vc.viewModel = viewModel
        vc.coordinator = self
        
        navigationController.pushViewController(vc, animated: true)
	}
    
    func showEditWatchlist(_ watchlist: Watchlist, viewModel: WatchlistViewModel) {
        let vc = UIStoryboard.named("Watchlist").instantiate(EditWatchlistDetailViewController.self)
        
        vc.watchlistType = .custom
        vc.viewModel = viewModel
        vc.coordinator = self
        vc.watchlistToEdit = watchlist
        
        navigationController.pushViewController(vc, animated: true)
    }
    
    func showEditSharedWatchlist(_ shared: SharedWatchlist, viewModel: WatchlistViewModel) {
        let vc = UIStoryboard.named("Watchlist").instantiate(EditWatchlistDetailViewController.self)
        
        vc.watchlistType = .shared
        vc.viewModel = viewModel
        vc.coordinator = self
        vc.sharedWatchlistToEdit = shared
        
        navigationController.pushViewController(vc, animated: true)
    }
	
		// In WatchlistCoordinator.swift
	
		// ... existing init ...
	
		// Step 1: Trigger Popup
	func showAddOptions(from viewController: UIViewController, sender: Any? = nil, targetWatchlistId: UUID? = nil, viewModel: WatchlistViewModel? = nil) {
		self.targetWatchlistId = targetWatchlistId
		self.viewModel = viewModel
		
		let alert = UIAlertController(title: "Add to Watchlist", message: nil, preferredStyle: .actionSheet)
		
			// 1. UPDATED: Add to Observed -> Direct Flow
		alert.addAction(UIAlertAction(title: "Add to Observed", style: .default, handler: { _ in
			self.currentMode = .observed
			self.processedBirds = [] // Reset processed birds
			self.birdQueue = []      // No queue needed for single create
									 // Direct call to show detail with nil bird (indicating Create Mode)
			self.showBirdDetail(bird: nil, mode: .observed)
		}))
		
		alert.addAction(UIAlertAction(title: "Add to Unobserved", style: .default, handler: { _ in
			self.showSpeciesSelection(mode: .unobserved)
		}))
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		
			// ... (Popover presentation code remains the same) ...
		if let popoverController = alert.popoverPresentationController {
			if let barButtonItem = sender as? UIBarButtonItem {
				popoverController.barButtonItem = barButtonItem
			} else if let sourceView = sender as? UIView {
				popoverController.sourceView = sourceView
				popoverController.sourceRect = sourceView.bounds
			} else {
				popoverController.sourceView = viewController.view
				popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
				popoverController.permittedArrowDirections = []
			}
		}
		viewController.present(alert, animated: true)
	}
	
		// ... existing showSpeciesSelection ...
		// ... existing startDetailLoop ...
	
		// Step 3 Update: Handle single entry save loop
	func showNextInLoop() {
			// If queue is empty, we are done
		if birdQueue.isEmpty {
				// Check if we have processed birds to save
			if !processedBirds.isEmpty {
				print("Loop finished. Updating data with \(processedBirds.count) birds.")
				
				if let vm = viewModel, let watchlistId = targetWatchlistId {
					let isObserved = (currentMode == .observed)
					vm.addBirds(processedBirds, to: watchlistId, asObserved: isObserved)
				}
			}
			
				// Navigate Back logic...
			if let smartWatchlistVC = navigationController.viewControllers.first(where: { $0 is SmartWatchlistViewController }) {
				navigationController.popToViewController(smartWatchlistVC, animated: true)
			} else {
				navigationController.popToRootViewController(animated: true)
			}
			return
		}
		
		let bird = birdQueue.removeFirst()
		showBirdDetail(bird: bird, mode: currentMode)
	}
	
		// Step 4 Update: Instantiate Observed Detail
	func showBirdDetail(bird: Bird?, mode: WatchlistMode) {
        let storyboard = UIStoryboard.named("Watchlist")
		
		if mode == .unobserved {
            let vc = storyboard.instantiate(UnobservedDetailViewController.self)
			vc.coordinator = self
			vc.bird = bird
			navigationController.pushViewController(vc, animated: true)
			return
		}
		
			// NEW: Handle Observed Mode
		if mode == .observed {
				// Using the Storyboard ID "ObservedDetailViewController"
            let vc = storyboard.instantiate(ObservedDetailViewController.self)
			
			vc.coordinator = self
            vc.viewModel = self.viewModel
			vc.bird = bird // Will be nil for "Add New"
			
				// Push directly onto navigation stack
			navigationController.pushViewController(vc, animated: true)
			return
		}
		
		print("Error: Unknown mode: \(mode)")
	}
}
