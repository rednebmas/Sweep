//
//  PushAPIClient.swift
//  Sweep
//

import Foundation

class PushAPIClient {
    static let shared = PushAPIClient()

    private let baseURL: String
    private let apiKey: String

    private init() {
        baseURL = Bundle.main.infoDictionary?["PUSH_API_BASE_URL"] as? String ?? ""
        apiKey = Bundle.main.infoDictionary?["PUSH_API_KEY"] as? String ?? ""
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

    func registerDevice(email: String, deviceToken: String, authCode: String) async {
        let body = ["email": email, "deviceToken": deviceToken, "authCode": authCode]
        if await post("registerDevice", body: body) {
            print("Device registered for push notifications")
        }
    }

    func appOpened(email: String) async {
        if await post("appOpened", body: ["email": email]) {
            print("App opened notification sent")
        }
    }
}
