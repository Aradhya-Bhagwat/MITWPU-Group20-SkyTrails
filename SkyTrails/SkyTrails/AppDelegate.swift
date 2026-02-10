//
//  AppDelegate.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		// Call to add Rose-ringed Parakeet to My Watchlist (for one-time execution)
        // Uncomment the line below, run the app once, then re-comment it.
        // WatchlistManager.shared.addRoseRingedParakeetToMyWatchlist()
        
        // Seed Home Data (Hotspots, Migrations, Observations)
        Task {
            print("🌍 [AppDelegate] Starting Home Data Seeding...")
            do {
                try await HomeDataSeeder.shared.seed(modelContext: WatchlistManager.shared.context)
            } catch {
                print("❌ [AppDelegate] Home Data Seeding Failed: \(error)")
            }
        }
        
		return true
	}

	// MARK: UISceneSession Lifecycle

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		// Called when a new scene session is being created.
		// Use this method to select a configuration to create the new scene with.
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
		// Called when the user discards a scene session.
		// If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
		// Use this method to release any resources that were specific to the discarded scenes, as they will not return.
	}


}

