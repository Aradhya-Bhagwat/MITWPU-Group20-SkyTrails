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

        // Observe auth state changes
        authObserver = NotificationCenter.default.addObserver(
            forName: UserSession.authStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.routeToCurrentSessionRoot()
        }

        // Restore session and connect realtime
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
    
    // MARK: - Foreground/Background Handling
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Reconnect realtime when coming back to foreground
        Task { @MainActor in
            await handleForegroundReconnect()
        }
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Keep connection alive briefly (iOS allows ~30s)
        // No immediate action needed - let iOS manage WebSocket lifecycle
        print("📱 [SceneDelegate] Entered background - connection maintained")
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
    
    // MARK: - Realtime Reconnection
    
    private func handleForegroundReconnect() async {
        guard UserSession.shared.isAuthenticatedWithSupabase() else { return }
        
        // Check if realtime is connected, reconnect if needed
        if RealtimeSyncService.shared.connectionState != .connected {
            print("📱 [SceneDelegate] Reconnecting realtime on foreground...")
            do {
                try await RealtimeSyncService.shared.connect()
                try await RealtimeSyncService.shared.subscribeAll()
            } catch {
                print("📱 [SceneDelegate] Failed to reconnect realtime: \(error.localizedDescription)")
            }
        }
        
        // Process any pending sync operations
        await BackgroundSyncAgent.shared.syncAll()
    }

    deinit {
        if let authObserver {
            NotificationCenter.default.removeObserver(authObserver)
        }
    }
}
