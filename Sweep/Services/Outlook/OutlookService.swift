//
//  OutlookService.swift
//  Sweep

import Foundation

class OutlookService {
    let auth: OutlookAuth
    let baseURL = "https://graph.microsoft.com/v1.0/me"
    private var bodyCache: [String: String] = [:]
    private var attachmentCache: [String: [EmailAttachment]] = [:]

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

    func getCachedAttachments(_ messageId: String) -> [EmailAttachment]? {
        attachmentCache[messageId]
    }

    func cacheAttachments(_ messageId: String, attachments: [EmailAttachment]) {
        attachmentCache[messageId] = attachments
    }

    func clearCache() {
        bodyCache.removeAll()
        attachmentCache.removeAll()
    }

    func authorizedRequest(_ url: URL) async throws -> URLRequest {
        try await auth.refreshTokenIfNeeded()
        guard let token = auth.token else { throw OutlookError.notAuthenticated }
        return HTTPClient.bearerRequest(url: url, token: token)
    }

}

extension OutlookService: AuthenticatedHTTPService {
    static func httpError(status: Int, data: Data) -> Error {
        if status == 401 { return OutlookError.notAuthenticated }
        return OutlookError.apiError(String(data: data, encoding: .utf8) ?? "Invalid response")
    }
}
