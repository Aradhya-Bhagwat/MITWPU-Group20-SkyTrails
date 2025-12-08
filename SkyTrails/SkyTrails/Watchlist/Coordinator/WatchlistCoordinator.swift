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
	private var currentMode: WatchlistMode = .observed
	
	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}
	
	func start() {
			// Entry point logic if needed
	}
	
		// Step 1: Trigger Popup
	func showAddOptions(from viewController: UIViewController, sender: Any? = nil) {
		let alert = UIAlertController(title: "Add to Watchlist", message: nil, preferredStyle: .actionSheet)
		
		alert.addAction(UIAlertAction(title: "Add to Observed", style: .default, handler: { _ in
			self.showSpeciesSelection(mode: .observed)
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
		vc.viewModel = WatchlistViewModel() // Inject existing or new VM
		
		navigationController.pushViewController(vc, animated: true)
	}
	
		// Step 3: Start Detail Entry Loop
	func startDetailLoop(birds: [Bird], mode: WatchlistMode) {
		self.birdQueue = birds
		self.currentMode = mode
		showNextInLoop()
	}
	
	func showNextInLoop() {
		guard !birdQueue.isEmpty else {
				// Loop finished
			navigationController.popToRootViewController(animated: true)
			return
		}
		
		let bird = birdQueue.removeFirst()
		showBirdDetail(bird: bird, mode: currentMode)
	}
	
	func showBirdDetail(bird: Bird?, mode: WatchlistMode) {
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "SmartFormViewController") as? SmartFormViewController else { return }
		
		vc.coordinator = self
		
			// FIXED: Correct mapping of WatchlistMode to ScreenMode
		switch mode {
			case .create:
				vc.mode = .newWatchlist
				
			case .observed:
					// Adding to OBSERVED = logging a bird you just saw
					// This is an UNKNOWN species - need to capture new details
				vc.mode = .newSpecies
				
			case .unobserved:
					// Adding to UNOBSERVED = adding a bird you WANT to see
					// This is a KNOWN species - user selected it from the list
				vc.mode = .knownSpecies
				vc.bird = bird
		}
		
			// If we are in a loop, we push. When "Save" is tapped on VC, it calls coordinator.showNextInLoop()
		navigationController.pushViewController(vc, animated: true)
	}
	
		// Step 4: Create Watchlist
	func showCreateWatchlist() {
			// Reuses SmartFormViewController in 'create' mode
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "SmartFormViewController") as? SmartFormViewController else { return }
		
		vc.coordinator = self
		vc.mode = .newWatchlist
		
		navigationController.pushViewController(vc, animated: true)
	}
}
