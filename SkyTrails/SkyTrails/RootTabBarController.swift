//
//  RottTabBarController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class RootTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewControllers = [
            loadFeature(storyboard: "Home",
                        title: "Home",
                        systemImage: "house"),
            
            loadFeature(storyboard: "Watchlist",
                        title: "Watchlist",
                        systemImage: "list.number"),
            
            loadFeature(storyboard: "Identification",
                        title: "ID",
                        systemImage: "sparkle.magnifyingglass")
        ]
    }
    
    var fakechange = "haha"
    private func loadFeature(storyboard: String,
                             title: String,
                             systemImage: String) -> UIViewController {
        
        let nav = UIStoryboard(name: storyboard, bundle: nil)
            .instantiateInitialViewController() as! UINavigationController
        
        nav.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImage),
            selectedImage: nil
        )
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }
}
