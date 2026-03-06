
import Foundation
import UserNotifications
import SwiftData
import UIKit

enum ReminderTrigger: String, CaseIterable, Codable, Sendable {
    case twoWeeksBeforeStart = "2w_start"
    case oneWeekBeforeStart = "1w_start"
    case oneDayBeforeStart = "1d_start"
    case oneWeekBeforeEnd = "1w_end"
    case oneDayBeforeEnd = "1d_end"
    
    var daysOffset: Int {
        switch self {
        case .twoWeeksBeforeStart: return -14
        case .oneWeekBeforeStart: return -7
        case .oneDayBeforeStart: return -1
        case .oneWeekBeforeEnd: return -7
        case .oneDayBeforeEnd: return -1
        }
    }
    
    var isStartTrigger: Bool {
        switch self {
        case .twoWeeksBeforeStart, .oneWeekBeforeStart, .oneDayBeforeStart:
            return true
        case .oneWeekBeforeEnd, .oneDayBeforeEnd:
            return false
        }
    }
    
    func message(for birdName: String) -> String {
        switch self {
        case .twoWeeksBeforeStart:
            return "\(birdName) observation window starts in 2 weeks!"
        case .oneWeekBeforeStart:
            return "\(birdName) observation window starts next week!"
        case .oneDayBeforeStart:
            return "\(birdName) observation window starts tomorrow!"
        case .oneWeekBeforeEnd:
            return "\(birdName) observation window ends in 1 week!"
        case .oneDayBeforeEnd:
            return "Last day to observe \(birdName) tomorrow!"
        }
    }
}

actor NotificationService {
    
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    private let reminderTimeKey = "kReminderTimeHour"
    private let reminderMinuteKey = "kReminderTimeMinute"
    
    private let notificationCategoryIdentifier = "BIRD_REMINDER"
    private let snoozeActionIdentifier = "SNOOZE_ACTION"
    
    private init() {}
    
    var reminderTime: DateComponents {
        get {
            let hour = UserDefaults.standard.integer(forKey: reminderTimeKey)
            let minute = UserDefaults.standard.integer(forKey: reminderMinuteKey)
            
            if hour == 0 && minute == 0 {
                var components = DateComponents()
                components.hour = 8
                components.minute = 0
                return components
            }
            
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return components
        }
        set {
            UserDefaults.standard.set(newValue.hour ?? 8, forKey: reminderTimeKey)
            UserDefaults.standard.set(newValue.minute ?? 0, forKey: reminderMinuteKey)
        }
    }
    
    func setReminderTime(hour: Int, minute: Int) async {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        reminderTime = components
        await rescheduleAllActiveReminders()
    }
    
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await center.requestAuthorization(options: options)
        return granted
    }
    
    func registerCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze 1 Hour",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: notificationCategoryIdentifier,
            actions: [snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
    }
    
    func scheduleReminders(for entry: WatchlistEntry) async {
        guard entry.notify_upcoming else {
            return
        }
        
        guard entry.status == .to_observe else {
            return
        }
        
        let entryId = entry.id
        let birdName = entry.bird?.name ?? "Bird"
        let startDate = entry.toObserveStartDate
        let endDate = entry.toObserveEndDate
        
        var scheduled = 0
        if let startDate = startDate {
            for trigger in [ReminderTrigger.twoWeeksBeforeStart, .oneWeekBeforeStart, .oneDayBeforeStart] {
                if await scheduleReminder(
                    entryId: entryId,
                    birdName: birdName,
                    trigger: trigger,
                    referenceDate: startDate
                ) {
                    scheduled += 1
                }
            }
        }
        if let endDate = endDate {
            for trigger in [ReminderTrigger.oneWeekBeforeEnd, .oneDayBeforeEnd] {
                if await scheduleReminder(
                    entryId: entryId,
                    birdName: birdName,
                    trigger: trigger,
                    referenceDate: endDate
                ) {
                    scheduled += 1
                }
            }
        }
    }
    
    private func scheduleReminder(
        entryId: UUID,
        birdName: String,
        trigger: ReminderTrigger,
        referenceDate: Date
    ) async -> Bool {
        let calendar = Calendar.current
        let triggerDate: Date?
        if await trigger.isStartTrigger {
            triggerDate = await calendar.date(byAdding: .day, value: trigger.daysOffset, to: referenceDate)
        } else {
            triggerDate = await calendar.date(byAdding: .day, value: trigger.daysOffset, to: referenceDate)
        }
        
        guard let fireDate = triggerDate else {
            return false
        }
        guard fireDate > Date() else {
            return false
        }
        let time = reminderTime
        var fireComponents = calendar.dateComponents([.year, .month, .day], from: fireDate)
        fireComponents.hour = time.hour ?? 8
        fireComponents.minute = time.minute ?? 0
        fireComponents.second = 0
        
        guard let finalFireDate = calendar.date(from: fireComponents) else {
            return false
        }
        let content = UNMutableNotificationContent()
        content.title = "Bird Watching Reminder"
        content.body = await trigger.message(for: birdName)
        content.sound = .default
        content.categoryIdentifier = notificationCategoryIdentifier
        content.userInfo = [
            "entryId": entryId.uuidString,
            "trigger": trigger.rawValue,
            "birdName": birdName
        ]
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: finalFireDate)
        let notificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let identifier = notificationIdentifier(entryId: entryId, trigger: trigger)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: notificationTrigger)
        
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
    
    func cancelReminders(for entryId: UUID) async {
        for trigger in ReminderTrigger.allCases {
            let identifier = notificationIdentifier(entryId: entryId, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }
    
    func cancelAllReminders() async {
        center.removeAllPendingNotificationRequests()
    }
    
    func snoozeReminder(entryId: UUID, trigger: ReminderTrigger, birdName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Bird Watching Reminder"
        content.body = await ReminderTrigger.oneDayBeforeStart.message(for: birdName)
        content.sound = .default
        content.categoryIdentifier = notificationCategoryIdentifier
        content.userInfo = [
            "entryId": entryId.uuidString,
            "trigger": trigger.rawValue,
            "birdName": birdName
        ]
        let triggerDate = Date().addingTimeInterval(3600)
        let calendar = Calendar.current
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let notificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let identifier = notificationIdentifier(entryId: entryId, trigger: trigger) + "_snooze"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: notificationTrigger)
        
        do {
            try await center.add(request)
        } catch {
        }
    }
    
    func rescheduleAllActiveReminders() async {
        await MainActor.run {
            do {
                let context = WatchlistManager.shared.context
                let descriptor = FetchDescriptor<WatchlistEntry>(
                    predicate: #Predicate<WatchlistEntry> { entry in
                        entry.notify_upcoming == true
                    }
                )
                let allEntries = try context.fetch(descriptor)
                let entries = allEntries.filter { $0.status == .to_observe }
                for entry in entries {
                    Task {
                        await self.cancelReminders(for: entry.id)
                        await self.scheduleReminders(for: entry)
                    }
                }
            } catch {
            }
        }
    }
    
    private func notificationIdentifier(entryId: UUID, trigger: ReminderTrigger) -> String {
        return "skytrails.entry.\(entryId.uuidString).\(trigger.rawValue)"
    }
    
    func getPendingReminders() async -> [UNNotificationRequest] {
        let requests = await center.pendingNotificationRequests()
        return requests.filter { $0.identifier.hasPrefix("skytrails.entry.") }
    }
}
