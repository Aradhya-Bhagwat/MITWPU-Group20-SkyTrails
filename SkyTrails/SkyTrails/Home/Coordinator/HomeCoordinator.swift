//
//  HomeCoordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import UIKit

class HomeCoordinator: Coordinator {
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let storyboard = UIStoryboard.named("Main") // Assuming Home is in Main for now, or "Home" if it exists
        // Placeholder:
        // let vc = storyboard.instantiate(HomeViewController.self)
        // navigationController.pushViewController(vc, animated: false)
    }
}
