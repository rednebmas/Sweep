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
    let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    let auth: AuthService
    private var bodyCache: [String: String] = [:]
    private var attachmentCache: [String: [EmailAttachment]] = [:]
    private var inFlightBodyRequests: [String: Task<String, Error>] = [:]
    var keptLabelId: String?

    var isAuthenticated: Bool { auth.isAuthenticated && auth.accessToken != nil }
    var userEmail: String? { auth.userEmail }
    var accountId: String { auth.accountId }

    init(auth: AuthService) {
        self.auth = auth
    }

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

    func getCachedAttachments(_ threadId: String) -> [EmailAttachment] {
        attachmentCache[threadId] ?? []
    }

    func cacheAttachments(_ threadId: String, attachments: [EmailAttachment]) {
        attachmentCache[threadId] = attachments
    }

    func clearCache() {
        bodyCache.removeAll()
        attachmentCache.removeAll()
        keptLabelId = nil
    }

    func isInlineImage(_ payload: PayloadFullResponse) -> Bool {
        guard let mimeType = payload.mimeType, mimeType.hasPrefix("image/") else { return false }
        return payload.headers?.contains { $0.name.lowercased() == "content-id" } ?? false
    }

    // MARK: - Auth Passthrough

    func signIn() async throws {
        try await auth.signIn()
        await restoreKeptThreads()
    }

    func signOut() {
        auth.signOut()
        clearCache()
    }

    // MARK: - API Helpers

    func authorizedRequest(_ url: URL) async throws -> URLRequest {
        try await auth.refreshTokenIfNeeded()
        guard let token = auth.accessToken else { throw GmailError.notAuthenticated }
        return HTTPClient.bearerRequest(url: url, token: token)
    }

}

extension GmailService: AuthenticatedHTTPService {
    static func httpError(status: Int, data: Data) -> Error {
        if status == -1 { return GmailError.invalidResponse }
        if status == 401 { return GmailError.notAuthenticated }
        return GmailError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
    }
}
