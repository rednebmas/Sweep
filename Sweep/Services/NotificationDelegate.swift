//
//  NotificationDelegate.swift
//  Sweep

import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    static let didTapNotification = Notification.Name("NotificationDelegate.didTapNotification")

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
            NotificationCenter.default.post(name: Self.didTapNotification, object: nil)
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
        do {
            let threads = try await BackgroundFetchService.fetchThreads()
            if !threads.isEmpty {
                try await UnifiedInboxService.shared.markAsRead(threads)
            }
            let newestDate = threads.map(\.timestamp).max() ?? Date()
            AppState.shared.updateEmailFetchTimestamp(newestEmailDate: newestDate)
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
            NotificationService.shared.clearNewEmailNotifications()
        } catch {
            print("Failed to mark all as read: \(error)")
        }
    }
}
