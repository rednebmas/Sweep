//
//  GmailService.swift
//  Sweep
//

import Foundation
import Combine

enum GmailError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to Gmail"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "Gmail API error: \(message)"
        case .invalidResponse:
            return "Invalid response from Gmail"
        }
    }
}

@MainActor
class GmailService: ObservableObject {
    static let shared = GmailService()

    let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let authService = AuthService.shared
    private var bodyCache: [String: String] = [:]
    private var inFlightBodyRequests: [String: Task<String, Error>] = [:]

    var isAuthenticated: Bool { authService.isAuthenticated && authService.accessToken != nil }
    var userEmail: String? { authService.userEmail }

    private init() {}

    func getCachedBody(_ threadId: String) -> String? {
        bodyCache[threadId]
    }

    func cacheBody(_ threadId: String, body: String) {
        bodyCache[threadId] = body
    }

    func getInFlightRequest(_ threadId: String) -> Task<String, Error>? {
        inFlightBodyRequests[threadId]
    }

    func setInFlightRequest(_ threadId: String, task: Task<String, Error>?) {
        inFlightBodyRequests[threadId] = task
    }

    func clearCache() {
        bodyCache.removeAll()
    }

    // MARK: - Auth Passthrough

    func signIn() async throws {
        try await authService.signIn()
    }

    func signOut() {
        authService.signOut()
    }

    // MARK: - API Helpers

    func authorizedRequest(_ url: URL) async throws -> URLRequest {
        try await authService.refreshTokenIfNeeded()

        guard let token = authService.accessToken else {
            throw GmailError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GmailError.notAuthenticated
        }

        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError(errorMessage)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
