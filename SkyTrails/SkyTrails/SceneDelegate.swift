import UIKit
import GoogleSignIn

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {

        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)

        let isLoggedIn = false/*UserDefaults.standard.bool(forKey: "isLoggedIn")*/

        print("Is Logged In:", isLoggedIn) // Debug

        if isLoggedIn {

            // 👉 Load MAIN storyboard
            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            let mainVC = storyboard.instantiateViewController(
                withIdentifier: "RootTabBarController"
            )

            window?.rootViewController = mainVC

        } else {

            // 👉 Load ONBOARD storyboard
            let storyboard = UIStoryboard(name: "Onboard", bundle: nil)

            let startVC = storyboard.instantiateViewController(
                withIdentifier: "StartViewController"
            )

            window?.rootViewController = startVC
        }

        window?.makeKeyAndVisible()
    }

    // Google Sign-In callback
    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {

        guard let url = URLContexts.first?.url else { return }

        GIDSignIn.sharedInstance.handle(url)
    }
}
