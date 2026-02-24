//
//  NotificationService.swift
//  SkyTrails
//
//  Handles scheduling and management of bird observation reminders
//

import Foundation
import UserNotifications
import SwiftData
import UIKit

enum ReminderTrigger: String, CaseIterable, Codable {
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
    
    // MARK: - Configuration
    
    var reminderTime: DateComponents {
        get {
            let hour = UserDefaults.standard.integer(forKey: reminderTimeKey)
            let minute = UserDefaults.standard.integer(forKey: reminderMinuteKey)
            
            if hour == 0 && minute == 0 {
                // Default: 8:00 AM
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
        
        print("🔔 [NotificationService] Reminder time set to \(hour):\(String(format: "%02d", minute))")
        
        // Reschedule all active reminders with new time
        await rescheduleAllActiveReminders()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await center.requestAuthorization(options: options)
        print("🔔 [NotificationService] Authorization \(granted ? "granted" : "denied")")
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
        print("🔔 [NotificationService] Registered notification categories")
    }
    
    // MARK: - Scheduling
    
    func scheduleReminders(for entry: WatchlistEntry) async {
        guard entry.notify_upcoming else {
            print("🔔 [NotificationService] Skipping schedule - reminders disabled for entry")
            return
        }
        
        guard entry.status == .to_observe else {
            print("🔔 [NotificationService] Skipping schedule - entry already observed")
            return
        }
        
        let entryId = entry.id
        let birdName = entry.bird?.name ?? "Bird"
        let startDate = entry.toObserveStartDate
        let endDate = entry.toObserveEndDate
        
        var scheduled = 0
        
        // Schedule start date reminders
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
        
        // Schedule end date reminders
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
        
        print("🔔 [NotificationService] Scheduled \(scheduled) reminders for \(birdName)")
    }
    
    private func scheduleReminder(
        entryId: UUID,
        birdName: String,
        trigger: ReminderTrigger,
        referenceDate: Date
    ) async -> Bool {
        let calendar = Calendar.current
        
        // Calculate the trigger date
        let triggerDate: Date?
        if trigger.isStartTrigger {
            // For start triggers, subtract days from start date
            triggerDate = calendar.date(byAdding: .day, value: trigger.daysOffset, to: referenceDate)
        } else {
            // For end triggers, subtract days from end date
            triggerDate = calendar.date(byAdding: .day, value: trigger.daysOffset, to: referenceDate)
        }
        
        guard let fireDate = triggerDate else {
            print("🔔 [NotificationService] Could not calculate fire date for \(trigger.rawValue)")
            return false
        }
        
        // Don't schedule if the date is in the past
        guard fireDate > Date() else {
            print("🔔 [NotificationService] Skipping \(trigger.rawValue) - date is in the past")
            return false
        }
        
        // Combine with reminder time (e.g., 8:00 AM)
        let time = reminderTime
        var fireComponents = calendar.dateComponents([.year, .month, .day], from: fireDate)
        fireComponents.hour = time.hour ?? 8
        fireComponents.minute = time.minute ?? 0
        fireComponents.second = 0
        
        guard let finalFireDate = calendar.date(from: fireComponents) else {
            return false
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Bird Watching Reminder"
        content.body = trigger.message(for: birdName)
        content.sound = .default
        content.categoryIdentifier = notificationCategoryIdentifier
        content.userInfo = [
            "entryId": entryId.uuidString,
            "trigger": trigger.rawValue,
            "birdName": birdName
        ]
        
        // Create trigger
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: finalFireDate)
        let notificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        // Create request with unique identifier
        let identifier = notificationIdentifier(entryId: entryId, trigger: trigger)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: notificationTrigger)
        
        do {
            try await center.add(request)
            print("🔔 [NotificationService] Scheduled \(trigger.rawValue) for \(finalFireDate)")
            return true
        } catch {
            print("❌ [NotificationService] Failed to schedule \(trigger.rawValue): \(error)")
            return false
        }
    }
    
    // MARK: - Cancellation
    
    func cancelReminders(for entryId: UUID) async {
        for trigger in ReminderTrigger.allCases {
            let identifier = notificationIdentifier(entryId: entryId, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
        print("🔔 [NotificationService] Cancelled all reminders for entry \(entryId)")
    }
    
    func cancelAllReminders() async {
        center.removeAllPendingNotificationRequests()
        print("🔔 [NotificationService] Cancelled all pending notifications")
    }
    
    // MARK: - Snooze
    
    func snoozeReminder(entryId: UUID, trigger: ReminderTrigger, birdName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Bird Watching Reminder"
        content.body = ReminderTrigger.oneDayBeforeStart.message(for: birdName) // Use appropriate message
        content.sound = .default
        content.categoryIdentifier = notificationCategoryIdentifier
        content.userInfo = [
            "entryId": entryId.uuidString,
            "trigger": trigger.rawValue,
            "birdName": birdName
        ]
        
        // Snooze for 1 hour
        let triggerDate = Date().addingTimeInterval(3600)
        let calendar = Calendar.current
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let notificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let identifier = notificationIdentifier(entryId: entryId, trigger: trigger) + "_snooze"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: notificationTrigger)
        
        do {
            try await center.add(request)
            print("🔔 [NotificationService] Snoozed reminder for 1 hour")
        } catch {
            print("❌ [NotificationService] Failed to snooze: \(error)")
        }
    }
    
    // MARK: - Reschedule All
    
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
                
                // Filter to only to_observe entries
                let entries = allEntries.filter { $0.status == .to_observe }
                
                print("🔔 [NotificationService] Rescheduling reminders for \(entries.count) to_observe entries")
                
                for entry in entries {
                    Task {
                        await self.cancelReminders(for: entry.id)
                        await self.scheduleReminders(for: entry)
                    }
                }
            } catch {
                print("❌ [NotificationService] Failed to fetch entries for reschedule: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func notificationIdentifier(entryId: UUID, trigger: ReminderTrigger) -> String {
        return "skytrails.entry.\(entryId.uuidString).\(trigger.rawValue)"
    }
    
    func getPendingReminders() async -> [UNNotificationRequest] {
        let requests = await center.pendingNotificationRequests()
        return requests.filter { $0.identifier.hasPrefix("skytrails.entry.") }
    }
}