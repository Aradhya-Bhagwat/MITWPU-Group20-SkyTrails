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
						title: "Identification",
						systemImage: "sparkle.magnifyingglass")
		]
	}

	private func loadFeature(storyboard: String,
							 title: String,
							 systemImage: String) -> UIViewController {

        let storyboard = UIStoryboard(name: storyboard, bundle: nil)
        guard let nav = storyboard.instantiateInitialViewController() as? UINavigationController else {
            let fallback = UINavigationController(rootViewController: UIViewController())
            fallback.tabBarItem = UITabBarItem(
                title: title,
                image: UIImage(systemName: systemImage),
                selectedImage: nil
            )
            return fallback
        }
		
		nav.tabBarItem = UITabBarItem(
			title: title,
			image: UIImage(systemName: systemImage),
			selectedImage: nil
		)
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
}
