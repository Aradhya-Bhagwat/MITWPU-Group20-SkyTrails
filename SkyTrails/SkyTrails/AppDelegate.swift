
import UIKit
import BackgroundTasks
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		setupNotifications()
		Task { @MainActor in
            await WatchlistManager.shared.performGlobalSeeding()
		}

        Task {
            await BackgroundSyncAgent.shared.registerBackgroundTasks()
        }
		
		return true
	}
	
	private func setupNotifications() {
		let center = UNUserNotificationCenter.current()
		center.delegate = NotificationDelegate.shared
		Task {
			do {
				let granted = try await NotificationService.shared.requestAuthorization()
				if granted {
					await NotificationService.shared.registerCategories()
				}
			} catch {
			}
		}
	}

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
	}

}
