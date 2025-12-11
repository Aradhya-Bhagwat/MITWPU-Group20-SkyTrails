//
//  Coordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

protocol Coordinator {
    var navigationController: UINavigationController { get set }
    func start()
}

class SharedCoordinator: Coordinator {
    
    var navigationController: UINavigationController
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    func start() {
        let storyboard = UIStoryboard.named("Shared")
        let vc = storyboard.instantiate(MapViewController.self)
        navigationController.pushViewController(vc, animated: true)
       
    }
 
}
