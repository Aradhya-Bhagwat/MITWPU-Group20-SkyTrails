//
//  RottTabBarController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

import UIKit

class RootTabBarController: UITabBarController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		viewControllers = [
			loadFeature(storyboard: "Home",
						id: "Home",
						title: "Home",
						systemImage: "house"),
			
			loadFeature(storyboard: "Watchlist",
						id: "Watchlist",
						title: "Watchlist",
						systemImage: "list.number"),
		
			loadFeature(storyboard: "Identification",
						id: "Identification",
						title: "Identification",
						systemImage: "sparkle.magnifyingglass")
			]

	}
	
	private func loadFeature(storyboard: String,
							 id: String,
							 title: String,
							 systemImage: String) -> UIViewController {
		
		let vc = UIStoryboard(name: storyboard, bundle: nil)
			.instantiateViewController(withIdentifier: id)
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem = UITabBarItem(
			title: title,
			image: UIImage(systemName: systemImage),
			selectedImage: nil
		)
        nav.navigationBar.prefersLargeTitles = true
		return nav
	}
}
