import UIKit

class RootTabBarController: UITabBarController, UITabBarControllerDelegate {

	override func viewDidLoad() {
		super.viewDidLoad()
		self.delegate = self
		
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

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Bypass the static full-screen onboarding view controller so the
		// interactive guided onboarding tour starts naturally from the Home Screen tab.
		/*
		if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
			let onboardingVC = OnboardingViewController()
			onboardingVC.modalPresentationStyle = .fullScreen
			self.present(onboardingVC, animated: true, completion: nil)
		}
		*/
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

    // MARK: - UITabBarControllerDelegate

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let viewControllers = tabBarController.viewControllers,
              let index = viewControllers.firstIndex(of: viewController) else {
            return true
        }
        
        // Index 0: Home (accessible to guests). Index 1: Watchlist, Index 2: Identification (requires login)
        if index > 0 && !UserSession.shared.isAuthenticatedWithSupabase() {
            presentAuthenticationFlow()
            return false
        }
        
        return true
    }

    func presentAuthenticationFlow() {
        let storyboard = UIStoryboard(name: "Onboard", bundle: nil)
        guard let startVC = storyboard.instantiateViewController(withIdentifier: "StartViewController") as? StartViewController else {
            return
        }
        
        startVC.modalPresentationStyle = .pageSheet
        self.present(startVC, animated: true, completion: nil)
    }
}
