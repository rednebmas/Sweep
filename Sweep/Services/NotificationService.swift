//
//  NotificationService.swift
//  Sweep
//

import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()

    private let notificationId = "sweep-morning-reminder"
    private(set) var deviceToken: String?

    private init() {}

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await scheduleMorningNotification()
                await registerForPushNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    @MainActor
    func registerForPushNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func setDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
    }

    func registerWithServer() async {
        guard let token = deviceToken else { return }
        guard let email = AuthService.shared.userEmail else { return }
        guard let authCode = AuthService.shared.serverAuthCode else { return }

        await PushAPIClient.shared.registerDevice(
            email: email,
            deviceToken: token,
            authCode: authCode
        )
    }

    func notifyAppOpened() async {
        guard let email = AuthService.shared.userEmail else { return }
        await PushAPIClient.shared.appOpened(email: email)
    }

    func scheduleMorningNotification() async {
        let center = UNUserNotificationCenter.current()

        // Remove existing notification
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        // Create content
        let content = UNMutableNotificationContent()
        content.title = "Sweep"
        content.body = "Time to check your inbox"
        content.sound = .default

        // Schedule for 8 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func cancelMorningNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
}
