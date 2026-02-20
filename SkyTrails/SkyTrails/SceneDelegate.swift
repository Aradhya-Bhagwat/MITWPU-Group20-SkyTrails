import UIKit
import GoogleSignIn

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var authObserver: NSObjectProtocol?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {

        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = makeLaunchPlaceholder()
        window?.makeKeyAndVisible()

        authObserver = NotificationCenter.default.addObserver(
            forName: UserSession.authStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.routeToCurrentSessionRoot()
        }

        Task { @MainActor in
            _ = await UserSession.shared.restoreSessionIfNeeded()
            if UserSession.shared.isAuthenticatedWithSupabase() {
                await WatchlistManager.shared.bindCurrentUserOwnership()
            }
            routeToCurrentSessionRoot()
        }
    }

    // Google Sign-In callback
    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {

        guard let url = URLContexts.first?.url else { return }

        GIDSignIn.sharedInstance.handle(url)
    }

    private func routeToCurrentSessionRoot() {
        guard let window else { return }

        let storyboardName = UserSession.shared.isAuthenticatedWithSupabase() ? "Main" : "Onboard"
        let identifier = UserSession.shared.isAuthenticatedWithSupabase()
            ? "RootTabBarController"
            : "StartViewController"

        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        let rootVC = storyboard.instantiateViewController(withIdentifier: identifier)

        window.rootViewController = rootVC
    }

    private func makeLaunchPlaceholder() -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground

        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()

        controller.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])

        return controller
    }

    deinit {
        if let authObserver {
            NotificationCenter.default.removeObserver(authObserver)
        }
    }
}
