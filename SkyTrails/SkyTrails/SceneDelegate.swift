import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var authObserver: NSObjectProtocol?
    private var sessionValidationTimer: Timer?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {

        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        ThemeService.applySavedTheme()
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
            if let callbackURL = connectionOptions.urlContexts.first?.url,
               SupabaseAuthService.shared.isOAuthRedirectURL(callbackURL) {
                await handleOAuthCallback(callbackURL)
                routeToCurrentSessionRoot()
                return
            }

            let restored = await UserSession.shared.restoreSessionIfNeeded()
            routeToCurrentSessionRoot()
        }
    }

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {

        guard let url = URLContexts.first?.url else { return }
        guard SupabaseAuthService.shared.isOAuthRedirectURL(url) else { return }

        Task { @MainActor in
            await handleOAuthCallback(url)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Task { @MainActor in
            await handleForegroundReconnect()
            startSessionValidationTimer()
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        sessionValidationTimer?.invalidate()
        sessionValidationTimer = nil
        RealtimeSyncService.shared.disconnect()
        Task {
            await BackgroundSyncAgent.shared.scheduleBackgroundSync()
        }
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

    private func handleOAuthCallback(_ url: URL) async {
        do {
            let authResult = try await SupabaseAuthService.shared.completeOAuthSignIn(from: url)
            let cached = UserSession.shared.currentUser

            let resolvedName = authResult.displayName
                ?? cached?.name
                ?? fallbackName(from: authResult.email)

            let resolvedPhoto = authResult.profilePhoto
                ?? cached?.profilePhoto
                ?? "defaultProfile"

            let user = User(
                user_id: authResult.userID,
                name: resolvedName,
                gender: authResult.gender ?? cached?.gender ?? "Not Specified",
                email: authResult.email,
                profilePhoto: resolvedPhoto
            )

            UserSession.shared.saveAuthenticatedUser(
                user,
                accessToken: authResult.accessToken,
                refreshToken: authResult.refreshToken
            )

            Task {
                try? await UserSyncService.shared.upsertUser(user)
            }
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }

    private func showAlert(message: String) {
        guard let root = window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Sign-In Failed",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        if let presented = root.presentedViewController {
            presented.present(alert, animated: true)
        } else {
            root.present(alert, animated: true)
        }
    }

    private func fallbackName(from email: String) -> String {
        let username = email.split(separator: "@").first.map(String.init) ?? "User"
        return username.isEmpty ? "User" : username
    }

    private func handleForegroundReconnect() async {
        guard let user = UserSession.shared.currentUser else { return }
        let sessionValid = await UserSession.shared.validateCurrentDeviceSession()
        if !sessionValid {
            UserSession.shared.logout()
            routeToCurrentSessionRoot()
            return
        }

        // Pull latest profile and data changes from other devices (like iPad)
        await UserSession.shared.syncProfileWithServer()
        do {
            _ = try await InitialSyncService.shared.performInitialSync(userId: user.user_id)
        } catch {
            print("DEBUG: SceneDelegate initial sync failed: \(error)")
        }
        do {
            try await IdentificationSyncService.shared.performSync(userId: user.user_id)
        } catch {
            print("DEBUG: SceneDelegate identification sync failed: \(error)")
        }

        if RealtimeSyncService.shared.connectionState == .disconnected {
            do {
                try await RealtimeSyncService.shared.connect()
                try await RealtimeSyncService.shared.subscribeAll()
            } catch {
            }
        }

        await BackgroundSyncAgent.shared.syncAll()
    }

    private func startSessionValidationTimer() {
        sessionValidationTimer?.invalidate()
        sessionValidationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.handleForegroundReconnect()
            }
        }
    }

    deinit {
        if let authObserver {
            NotificationCenter.default.removeObserver(authObserver)
        }
    }
}
