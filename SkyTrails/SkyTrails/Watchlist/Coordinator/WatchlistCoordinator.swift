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

class WatchlistCoordinator: Coordinator {
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
	
		// Step 1: Trigger Popup
	func showAddOptions(from viewController: UIViewController, sender: Any? = nil, targetWatchlistId: UUID? = nil, viewModel: WatchlistViewModel? = nil) {
        self.targetWatchlistId = targetWatchlistId
        self.viewModel = viewModel
        
		let alert = UIAlertController(title: "Add to Watchlist", message: nil, preferredStyle: .actionSheet)
		
		alert.addAction(UIAlertAction(title: "Add to Observed", style: .default, handler: { _ in
            print("user clicked observed")
			// self.showSpeciesSelection(mode: .observed)
		}))
		
		alert.addAction(UIAlertAction(title: "Add to Unobserved", style: .default, handler: { _ in
			self.showSpeciesSelection(mode: .unobserved)
		}))
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		
		if let popoverController = alert.popoverPresentationController {
			if let barButtonItem = sender as? UIBarButtonItem {
				popoverController.barButtonItem = barButtonItem
			} else if let sourceView = sender as? UIView {
				popoverController.sourceView = sourceView
				popoverController.sourceRect = sourceView.bounds
			} else {
					// Fallback for iPad if sender is unknown or not view/item: center it
				popoverController.sourceView = viewController.view
				popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
				popoverController.permittedArrowDirections = []
			}
		}
		
		viewController.present(alert, animated: true)
	}
	
		// Step 2: Screen #3 (Species Selection)
	func showSpeciesSelection(mode: WatchlistMode) {
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as? SpeciesSelectionViewController else { return }
		
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
	
	func showNextInLoop() {
		guard !birdQueue.isEmpty else {
				// Loop finished
            print("Loop finished. Updating data with \(processedBirds.count) birds.")
            
            if let vm = viewModel, let watchlistId = targetWatchlistId {
                let isObserved = (currentMode == .observed)
                vm.addBirds(processedBirds, to: watchlistId, asObserved: isObserved)
            }
            
            // Pop back to the Watchlist Detail (SmartWatchlistViewController)
            // We assume it's 2 steps back (SpeciesSelection -> UnobservedDetail -> ... -> SmartWatchlist)
            // Actually, we are in a loop of UnobservedDetailVCs.
            // The stack is [Home, SmartWatchlist, SpeciesSelection, UnobservedDetail, UnobservedDetail...]
            // We want to go back to SmartWatchlist.
            
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
    
    func saveBirdDetails(bird: Bird) {
        processedBirds.append(bird)
        showNextInLoop()
    }
	
	func showBirdDetail(bird: Bird?, mode: WatchlistMode) {
        if mode == .unobserved {
            let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
            guard let vc = storyboard.instantiateViewController(withIdentifier: "UnobservedDetailViewController") as? UnobservedDetailViewController else { return }
            
            vc.coordinator = self
            vc.bird = bird
            navigationController.pushViewController(vc, animated: true)
            return
        }
        
        print("Error: SmartFormViewController is missing. Implementation pending for mode: \(mode)")

	}
	
		// Step 4: Create Watchlist
	func showCreateWatchlist() {
        print("Error: SmartFormViewController is missing. Implementation pending for create watchlist.")

	}
}
