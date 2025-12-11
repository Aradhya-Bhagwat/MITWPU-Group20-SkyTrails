//
//  Coordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import UIKit
import Foundation

// The "Remote Control" protocol
protocol HomeNavigationDelegate: AnyObject {
    func didSelectAllSpots(watchlist: [PopularSpot], recommendations: [PopularSpot])
    func didSelectAllBirds(watchlist: [UpcomingBird], recommendations: [UpcomingBird])
    func didTapPredict() // Future use
}

class HomeCoordinator {
    
    // The coordinator owns the navigation controller
    var navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    // Entry point: Loads the Home Screen
    func start() {
        // 1. Load Home VC from Storyboard
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController else {
            fatalError("Could not find HomeViewController in Main.storyboard. Did you set the Storyboard ID?")
        }
        
        // 2. Assign the Coordinator as the delegate
        homeVC.coordinator = self
        
        // 3. Push it
        navigationController.pushViewController(homeVC, animated: true)
    }
}

// MARK: - Navigation Logic
extension HomeCoordinator: HomeNavigationDelegate {
    
    func didSelectAllSpots(watchlist: [PopularSpot], recommendations: [PopularSpot]) {
            // 1. Get the Storyboard
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            
            // 2. Load the specific screen by ID (matches what you just typed in Storyboard)
            guard let vc = storyboard.instantiateViewController(withIdentifier: "AllSpotsViewController") as? AllSpotsViewController else {
                fatalError("Could not find AllSpotsViewController in Storyboard")
            }
            
            // 3. Inject Data
            vc.watchlistData = watchlist
            vc.recommendationsData = recommendations
            
            // 4. Configure & Push
            vc.navigationItem.largeTitleDisplayMode = .never
            navigationController.pushViewController(vc, animated: true)
        }
        
        func didSelectAllBirds(watchlist: [UpcomingBird], recommendations: [UpcomingBird]) {
            // 1. Get the Storyboard
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            
            // 2. Load the specific screen by ID
            guard let vc = storyboard.instantiateViewController(withIdentifier: "AllUpcomingBirdsViewController") as? AllUpcomingBirdsViewController else {
                fatalError("Could not find AllUpcomingBirdsViewController in Storyboard")
            }
            
            // 3. Inject Data
            vc.watchlistData = watchlist
            vc.recommendationsData = recommendations
            
            // 4. Configure & Push
            vc.navigationItem.largeTitleDisplayMode = .never
            navigationController.pushViewController(vc, animated: true)
        }
    
    func didTapPredict() {
        print("Coordinator: Navigate to Prediction Flow")
        // navigationController.pushViewController(PredictionViewController(), animated: true)
    }
}
