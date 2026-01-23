//
//  NotificationDelegate.swift
//  Sweep

import UserNotifications
import UIKit

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == NotificationService.markAllReadAction {
            Task {
                await handleMarkAllRead()
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    @MainActor
    private func handleMarkAllRead() async {
        let fetchDate = AppState.shared.getEmailFetchDate()

        do {
            let threads = try await UnifiedInboxService.shared.fetchAllThreads(since: fetchDate)
            if !threads.isEmpty {
                try await UnifiedInboxService.shared.markAsRead(threads)
            }
            AppState.shared.recordAppOpen()
            UIApplication.shared.applicationIconBadgeNumber = 0
        } catch {
            print("Failed to mark all as read: \(error)")
        }
    }
}
