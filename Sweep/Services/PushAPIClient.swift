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

    func registerDevice(email: String, deviceToken: String, refreshToken: String) async {
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return }

        let url = URL(string: "\(baseURL)/registerDevice")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Sweep-Key")

        let body: [String: String] = [
            "email": email,
            "deviceToken": deviceToken,
            "refreshToken": refreshToken
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Device registered for push notifications")
            }
        } catch {
            print("Failed to register device: \(error)")
        }
    }

    func appOpened(email: String) async {
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return }

        let url = URL(string: "\(baseURL)/appOpened")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Sweep-Key")

        let body = ["email": email]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("App opened notification sent")
            }
        } catch {
            print("Failed to notify app opened: \(error)")
        }
    }
}
