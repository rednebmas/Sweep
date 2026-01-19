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

    @MainActor
    func registerAllAccountsWithServer() async {
        guard let token = deviceToken else { return }

        for account in AccountManager.shared.enabledAccounts {
            guard let provider = AccountManager.shared.provider(for: account.id) else { continue }

            switch account.providerType {
            case .gmail:
                guard let gmailProvider = provider as? GmailProvider,
                      let authCode = gmailProvider.serverAuthCode else { continue }
                await PushAPIClient.shared.registerGmailDevice(
                    email: account.email,
                    deviceToken: token,
                    authCode: authCode
                )
            case .outlook:
                guard let outlookProvider = provider as? OutlookProvider,
                      let authCode = outlookProvider.serverAuthCode else { continue }
                await PushAPIClient.shared.registerOutlookDevice(
                    email: account.email,
                    deviceToken: token,
                    authCode: authCode
                )
            }
        }
    }

    @MainActor
    func notifyAppOpened() async {
        for account in AccountManager.shared.enabledAccounts {
            let provider = account.providerType == .gmail ? "gmail" : "outlook"
            await PushAPIClient.shared.appOpened(email: account.email, provider: provider)
        }
    }

    func scheduleMorningNotification() async {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        let content = UNMutableNotificationContent()
        content.title = "Sweep"
        content.body = "Time to check your inbox"
        content.sound = .default

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
