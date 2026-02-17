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

        let storyboard: UIStoryboard
        let rootVC: UIViewController

        // ✅ Check using UserSession (NOT UserDefaults)
        if UserSession.shared.isLoggedIn() {

            storyboard = UIStoryboard(name: "Main", bundle: nil)

            rootVC = storyboard.instantiateViewController(
                withIdentifier: "RootTabBarController"
            )

            print("Auto Login: TRUE")

        } else {

            storyboard = UIStoryboard(name: "Onboard", bundle: nil)

            rootVC = storyboard.instantiateViewController(
                withIdentifier: "StartViewController"
            )

            print("Auto Login: FALSE")
        }

        window?.rootViewController = rootVC
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
