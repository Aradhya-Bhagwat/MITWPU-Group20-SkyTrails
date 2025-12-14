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
            loadFeature(storyboard: "Home", isInitial: true, title: "Home", systemImage: "house"),
            loadFeature(storyboard: "Watchlist", id: "Watchlist", title: "Watchlist", systemImage: "list.number"),
            loadFeature(storyboard: "Identification", id: "Identification", title: "ID", systemImage: "sparkle.magnifyingglass")
        ]
    }
    
    private func loadFeature(storyboard: String, id: String? = nil, isInitial: Bool = false, title: String, systemImage: String) -> UIViewController {
        let sb = UIStoryboard(name: storyboard, bundle: nil)
        
        let loadedVC: UIViewController
        if isInitial {
            // This is for storyboards where the initial VC is the one we want (like Home.storyboard's UINavigationController)
            guard let vc = sb.instantiateInitialViewController() else {
                fatalError("Expected initial view controller in \(storyboard) but found none.")
            }
            loadedVC = vc
        } else if let identifier = id {
            // This is for storyboards where we get a specific VC by its ID.
            loadedVC = sb.instantiateViewController(withIdentifier: identifier)
        } else {
            fatalError("You must provide an ID or set isInitial to true.")
        }
        
        // If the loaded VC is already a navigation controller, use it directly.
        if let nav = loadedVC as? UINavigationController {
            nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: systemImage), selectedImage: nil)
            return nav
        }
        
        // Otherwise, wrap the loaded VC in a new navigation controller.
        let nav = UINavigationController(rootViewController: loadedVC)
        nav.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImage),
            selectedImage: nil
        )
        
        return nav
    }
}
