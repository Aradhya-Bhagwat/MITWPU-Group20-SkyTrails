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
        let storyboard = UIStoryboard.named("SharedStoryboard")
        let vc = storyboard.instantiate(MapViewController.self)
        navigationController.pushViewController(vc, animated: true)
       
    }
 
}
