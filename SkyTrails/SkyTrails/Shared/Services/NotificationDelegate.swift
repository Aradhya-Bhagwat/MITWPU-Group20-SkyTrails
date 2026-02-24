//
//  NotificationDelegate.swift
//  SkyTrails
//
//  Handles notification taps, deep links, and snooze actions
//

import Foundation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Presenting Notifications
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - Handling Notification Taps
    
    /// Handle notification tap (user interacted with notification)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("🔔 [NotificationDelegate] Received response: \(response.actionIdentifier)")
        
        // Handle snooze action
        if response.actionIdentifier == "SNOOZE_ACTION" {
            handleSnooze(userInfo)
            completionHandler()
            return
        }
        
        // Handle dismiss action
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // User tapped the notification itself - navigate to entry
            handleDeepLink(userInfo)
        }
        
        completionHandler()
    }
    
    // MARK: - Deep Link Navigation
    
    private func handleDeepLink(_ userInfo: [AnyHashable: Any]) {
        guard let entryIdString = userInfo["entryId"] as? String,
              let entryId = UUID(uuidString: entryIdString) else {
            print("🔔 [NotificationDelegate] Could not extract entryId from notification")
            return
        }
        
        let birdName = userInfo["birdName"] as? String ?? "Bird"
        let triggerRaw = userInfo["trigger"] as? String ?? ""
        
        print("🔔 [NotificationDelegate] Deep link to entry: \(entryId), bird: \(birdName), trigger: \(triggerRaw)")
        
        // Post notification for app to handle navigation
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showWatchlistEntry,
                object: nil,
                userInfo: [
                    "entryId": entryId,
                    "birdName": birdName
                ]
            )
        }
    }
    
    // MARK: - Snooze Handling
    
    private func handleSnooze(_ userInfo: [AnyHashable: Any]) {
        guard let entryIdString = userInfo["entryId"] as? String,
              let entryId = UUID(uuidString: entryIdString),
              let triggerRaw = userInfo["trigger"] as? String,
              let trigger = ReminderTrigger(rawValue: triggerRaw) else {
            print("🔔 [NotificationDelegate] Could not extract data for snooze")
            return
        }
        
        let birdName = userInfo["birdName"] as? String ?? "Bird"
        
        print("🔔 [NotificationDelegate] Snoozing reminder for \(birdName)")
        
        Task {
            await NotificationService.shared.snoozeReminder(
                entryId: entryId,
                trigger: trigger,
                birdName: birdName
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showWatchlistEntry = Notification.Name("ShowWatchlistEntry")
}
