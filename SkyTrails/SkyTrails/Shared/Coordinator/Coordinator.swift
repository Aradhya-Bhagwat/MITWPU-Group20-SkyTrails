//
//  Coordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class SharedCoordinator {
    
    var navigationController: UINavigationController
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    func openSharedMapScreen() {
        startMapScreen()
    }

    func startMapScreen() {
        let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            navigationController.pushViewController(vc, animated: true)
        }
    }
 
}
