
import Foundation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if response.actionIdentifier == "SNOOZE_ACTION" {
            handleSnooze(userInfo)
            completionHandler()
            return
        }
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            handleDeepLink(userInfo)
        }
        
        completionHandler()
    }
    
    private func handleDeepLink(_ userInfo: [AnyHashable: Any]) {
        guard let entryIdString = userInfo["entryId"] as? String,
              let entryId = UUID(uuidString: entryIdString) else {
            return
        }
        
        let birdName = userInfo["birdName"] as? String ?? "Bird"
        let triggerRaw = userInfo["trigger"] as? String ?? ""
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
    
    private func handleSnooze(_ userInfo: [AnyHashable: Any]) {
        guard let entryIdString = userInfo["entryId"] as? String,
              let entryId = UUID(uuidString: entryIdString),
              let triggerRaw = userInfo["trigger"] as? String,
              let trigger = ReminderTrigger(rawValue: triggerRaw) else {
            return
        }
        
        let birdName = userInfo["birdName"] as? String ?? "Bird"
        Task {
            await NotificationService.shared.snoozeReminder(
                entryId: entryId,
                trigger: trigger,
                birdName: birdName
            )
        }
    }
}

extension Notification.Name {
    static let showWatchlistEntry = Notification.Name("ShowWatchlistEntry")
}
