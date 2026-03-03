//
//  PushAPIClient.swift
//  Sweep
//

import Foundation

class PushAPIClient {
    static let shared = PushAPIClient()

    private let baseURL: String
    private let apiKey: String
    private let apnsSandbox: String

    private init() {
        baseURL = Bundle.main.infoDictionary?["PUSH_API_BASE_URL"] as? String ?? ""
        apiKey = Bundle.main.infoDictionary?["PUSH_API_KEY"] as? String ?? ""
        #if DEBUG
        apnsSandbox = "true"
        #else
        apnsSandbox = "false"
        #endif
    }

    private func post(_ endpoint: String, body: [String: String]) async -> Bool {
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return false }

        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Sweep-Key")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func registerGmailDevice(email: String, deviceToken: String, authCode: String) async {
        let body = ["email": email, "deviceToken": deviceToken, "authCode": authCode, "provider": "gmail", "apnsSandbox": apnsSandbox]
        if await post("registerDevice", body: body) {
            print("Gmail device registered for push notifications")
        }
    }

    func registerOutlookDevice(email: String, deviceToken: String, authCode: String) async {
        let body = ["email": email, "deviceToken": deviceToken, "authCode": authCode, "provider": "outlook", "apnsSandbox": apnsSandbox]
        if await post("registerDevice", body: body) {
            print("Outlook device registered for push notifications")
        }
    }

    func registerIMAPDevice(email: String, deviceToken: String, password: String, host: String, port: UInt32) async {
        let body = [
            "email": email,
            "deviceToken": deviceToken,
            "password": password,
            "host": host,
            "port": String(port),
            "provider": "imap",
            "apnsSandbox": apnsSandbox
        ]
        if await post("registerDevice", body: body) {
            print("IMAP device registered for push notifications")
        }
    }

    func appOpened(email: String, provider: String) async {
        if await post("appOpened", body: ["email": email, "provider": provider]) {
            print("App opened notification sent for \(provider)")
        }
    }
}
