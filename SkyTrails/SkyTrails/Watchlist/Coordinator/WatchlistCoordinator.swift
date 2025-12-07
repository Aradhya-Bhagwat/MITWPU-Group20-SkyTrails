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
    var navigationController: UINavigationController
    
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
    func showAddOptions(from viewController: UIViewController) {
        let alert = UIAlertController(title: "Add to Watchlist", message: "Select a category", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Add to Observed", style: .default, handler: { _ in
            self.showSpeciesSelection(mode: .observed)
        }))
        
        alert.addAction(UIAlertAction(title: "Add to Unobserved", style: .default, handler: { _ in
            self.showSpeciesSelection(mode: .unobserved)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        viewController.present(alert, animated: true)
    }
    
    // Step 2: Screen #3 (Species Selection)
    func showSpeciesSelection(mode: WatchlistMode) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as? SpeciesSelectionViewController else { return }
        
        vc.coordinator = self
        vc.mode = mode
        vc.viewModel = WatchlistViewModel() // In real app, inject existing VM
        
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
        guard let vc = storyboard.instantiateViewController(withIdentifier: "BirdDetailViewController") as? BirdDetailViewController else { return }
        
        vc.coordinator = self
        vc.bird = bird
        vc.mode = mode
        
        // If we are in a loop, we push. When "Save" is tapped on VC, it calls coordinator.showNextInLoop()
        navigationController.pushViewController(vc, animated: true)
    }
    
    // Step 4: Create Watchlist
    func showCreateWatchlist() {
        // Reuses BirdDetailViewController in 'create' mode
        showBirdDetail(bird: nil, mode: .create)
    }
}

