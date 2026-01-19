//
//  OutlookService.swift
//  Sweep

import Foundation

class OutlookService {
    let auth: OutlookAuth
    let baseURL = "https://graph.microsoft.com/v1.0/me"
    private var bodyCache: [String: String] = [:]

    var accountId: String { auth.accountId }
    var isAuthenticated: Bool { auth.isAuthenticated }

    init(auth: OutlookAuth) {
        self.auth = auth
    }

    func getCachedBody(_ messageId: String) -> String? {
        bodyCache[messageId]
    }

    func cacheBody(_ messageId: String, body: String) {
        bodyCache[messageId] = body
    }

    func clearCache() {
        bodyCache.removeAll()
    }

    func authorizedRequest(_ url: URL) async throws -> URLRequest {
        try await auth.refreshTokenIfNeeded()

        guard let token = auth.token else {
            throw OutlookError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await executeRequest(request)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func performVoidRequest(_ request: URLRequest) async throws {
        _ = try await executeRequest(request)
    }

    private func executeRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OutlookError.apiError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw OutlookError.notAuthenticated
        }

        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OutlookError.apiError(errorMessage)
        }

        return data
    }
}
