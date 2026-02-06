import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")

        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if isLoggedIn {

            let mainVC = storyboard.instantiateViewController(
                withIdentifier: "RootTabBarController"
            )

            window.rootViewController = mainVC

        } else {

            // Start/Login/Signup screen
            let authVC = storyboard.instantiateInitialViewController()

            window.rootViewController = authVC
        }

        self.window = window
        window.makeKeyAndVisible()
    }
}
