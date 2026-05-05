
import UIKit
import BackgroundTasks
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("DEBUG AppDelegate: application didFinishLaunching")
		ThemeService.applySavedTheme()
		Task { @MainActor in
            print("DEBUG AppDelegate: Starting global seeding")
            await WatchlistManager.shared.performGlobalSeeding()
            print("DEBUG AppDelegate: Global seeding finished")
		}

        BackgroundSyncAgent.shared.registerBackgroundTasks()
		
		return true
	}

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
	}

}
