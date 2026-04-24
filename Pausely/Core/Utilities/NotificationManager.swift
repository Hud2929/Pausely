//
//  NotificationManager.swift
//  Pausely
//
//  Local Notifications for Renewal Reminders
//

import Foundation
@preconcurrency import UserNotifications
import UIKit

@Observable
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    
    // MARK: - State
    private(set) var isAuthorized = false
    private(set) var pendingNotifications: [UNNotificationRequest] = []
    
    // MARK: - Private Properties
    private let center = UNUserNotificationCenter.current()
    
    // MARK: - Initialization
    private init() {
        Task {
            await requestAuthorization()
            await loadPendingNotifications()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        let settings = await center.notificationSettings()
        
        guard settings.authorizationStatus == .notDetermined else {
            isAuthorized = settings.authorizationStatus == .authorized
            return
        }
        
        do {
            isAuthorized = try await center.requestAuthorization(
                options: [.alert, .sound, .badge, .provisional]
            )
            if isAuthorized {
                registerCategories()
            }
        } catch {
            isAuthorized = false
        }
    }
    
    // MARK: - Subscription Reminders
    
    func scheduleRenewalReminder(for subscription: Subscription) {
        guard isAuthorized else { return }
        
        // Cancel existing reminder
        cancelReminder(for: subscription.id)
        
        guard let daysUntil = subscription.daysUntilRenewal,
              daysUntil > subscription.notifyBeforeDays,
              let nextBilling = subscription.nextBillingDate else {
            return
        }
        
        // Calculate trigger date
        guard let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -subscription.notifyBeforeDays,
            to: nextBilling
        ) else { return }
        
        // Only schedule if in the future
        guard reminderDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "\(subscription.name) renews soon"
        content.body = "\(subscription.displayAmount) will be charged in \(subscription.notifyBeforeDays) days. Tap to review."
        content.sound = .default
        content.categoryIdentifier = "RENEWAL_REMINDER"
        content.userInfo = [
            "subscription_id": subscription.id.uuidString,
            "type": "renewal"
        ]
        
        // Create trigger for 9 AM on reminder date
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "renewal-\(subscription.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    func scheduleTrialEndingReminder(for subscription: Subscription) {
        guard isAuthorized,
              subscription.status == .trial,
              let trialEnd = subscription.trialEndsAt else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "\(subscription.name) trial ending"
        content.body = "Your trial ends tomorrow. You'll be charged \(subscription.displayAmount) / \(subscription.billingFrequency.shortDisplay)."
        content.sound = .default
        content.categoryIdentifier = "TRIAL_ENDING"
        content.userInfo = [
            "subscription_id": subscription.id.uuidString,
            "type": "trial_ending"
        ]
        
        // Trigger 1 day before trial ends at 10 AM
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: trialEnd) else { return }
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "trial-\(subscription.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    func schedulePriceIncreaseAlert(subscription: Subscription, oldPrice: Decimal, newPrice: Decimal) {
        guard isAuthorized else { return }
        
        let increase = ((newPrice - oldPrice) / oldPrice) * 100
        
        let content = UNMutableNotificationContent()
        content.title = "Price increase detected"
        content.body = "\(subscription.name) increased by \(String(format: "%.0f", Double(truncating: increase as NSNumber)))%. You're now paying \(subscription.displayAmount)."
        content.sound = .default
        content.categoryIdentifier = "PRICE_INCREASE"
        content.userInfo = [
            "subscription_id": subscription.id.uuidString,
            "type": "price_increase"
        ]
        
        let request = UNNotificationRequest(
            identifier: "price-\(subscription.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )
        
        center.add(request)
    }
    
    // MARK: - Cancellation
    
    func schedulePauseResumeReminder(for subscription: Subscription, resumeDate: Date) {
        guard isAuthorized else { return }

        cancelPauseReminder(for: subscription.id)

        guard resumeDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subscription.name) pause ending"
        content.body = "Your subscription will automatically resume tomorrow. Tap to review or resume now."
        content.sound = .default
        content.categoryIdentifier = "PAUSE_RESUME"
        content.userInfo = [
            "subscription_id": subscription.id.uuidString,
            "type": "pause_resume"
        ]

        // Notify 1 day before resume at 10 AM
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: resumeDate) else { return }
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "pause-\(subscription.id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func schedulePauseReminder(for subscription: Subscription, reminderDate: Date, pauseURL: String?) {
        guard isAuthorized else { return }
        cancelPauseReminder(for: subscription.id)
        guard reminderDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Reminder: Pause \(subscription.name)"
        content.body = "Tap to open \(subscription.name)'s pause page."
        content.sound = .default
        content.categoryIdentifier = "PAUSE_REMINDER"
        content.userInfo = [
            "subscription_id": subscription.id.uuidString,
            "type": "pause_reminder",
            "pause_url": pauseURL ?? ""
        ]
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pause-reminder-\(subscription.id.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelPauseReminder(for subscriptionId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "pause-\(subscriptionId.uuidString)",
            "pause-reminder-\(subscriptionId.uuidString)"
        ])
    }

    func cancelReminder(for subscriptionId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "renewal-\(subscriptionId.uuidString)",
            "trial-\(subscriptionId.uuidString)",
            "pause-\(subscriptionId.uuidString)"
        ])
    }
    
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }
    
    func rescheduleAllReminders(for subscriptions: [Subscription]) {
        cancelAllReminders()
        
        for subscription in subscriptions where subscription.status == .active {
            scheduleRenewalReminder(for: subscription)
        }
    }
    
    // MARK: - Private Methods
    
    private func registerCategories() {
        // Renewal reminder actions
        let cancelAction = UNNotificationAction(
            identifier: "CANCEL_SUB",
            title: "Help Me Cancel",
            options: .foreground
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind Tomorrow",
            options: []
        )
        
        let renewalCategory = UNNotificationCategory(
            identifier: "RENEWAL_REMINDER",
            actions: [cancelAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Trial ending actions
        let keepAction = UNNotificationAction(
            identifier: "KEEP_TRIAL",
            title: "Keep Subscription",
            options: .foreground
        )
        
        let cancelTrialAction = UNNotificationAction(
            identifier: "CANCEL_TRIAL",
            title: "Cancel Before Billing",
            options: .destructive
        )
        
        let trialCategory = UNNotificationCategory(
            identifier: "TRIAL_ENDING",
            actions: [keepAction, cancelTrialAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Pause resume actions
        let resumeNowAction = UNNotificationAction(
            identifier: "RESUME_NOW",
            title: "Resume Now",
            options: .foreground
        )

        let pauseCategory = UNNotificationCategory(
            identifier: "PAUSE_RESUME",
            actions: [resumeNowAction],
            intentIdentifiers: [],
            options: []
        )

        let pauseReminderAction = UNNotificationAction(
            identifier: "OPEN_PAUSE_PAGE",
            title: "Open Pause Page",
            options: .foreground
        )

        let pauseReminderCategory = UNNotificationCategory(
            identifier: "PAUSE_REMINDER",
            actions: [pauseReminderAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([renewalCategory, trialCategory, pauseCategory, pauseReminderCategory])
    }
    
    private func loadPendingNotifications() async {
        pendingNotifications = await center.pendingNotificationRequests()
    }
}

// MARK: - App Delegate Extension
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle actions
        switch response.actionIdentifier {
        case "CANCEL_SUB":
            if let subId = userInfo["subscription_id"] as? String {
                NotificationCenter.default.post(
                    name: .cancelSubscriptionRequested,
                    object: nil,
                    userInfo: ["subscription_id": subId]
                )
            }
        case "SNOOZE":
            // Reschedule for tomorrow
            break
        case "OPEN_PAUSE_PAGE":
            if let pauseURL = userInfo["pause_url"] as? String, !pauseURL.isEmpty,
               let url = URL(string: pauseURL) {
                Task { @MainActor in
                    await UIApplication.shared.open(url)
                }
            } else if let subId = userInfo["subscription_id"] as? String {
                // Fallback: navigate to subscription detail so user can find cancel link
                NotificationCenter.default.post(
                    name: .openPausePageRequested,
                    object: nil,
                    userInfo: ["subscription_id": subId]
                )
            }
        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let cancelSubscriptionRequested = Notification.Name("cancelSubscriptionRequested")
    static let openPausePageRequested = Notification.Name("openPausePageRequested")
}
