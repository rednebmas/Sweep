//
//  IMAPService.swift
//  Sweep

import Foundation
import SwiftMail

class IMAPService {
    let credentials: IMAPCredentials
    private var bodyCache: [String: String] = [:]
    private var attachmentCache: [String: [EmailAttachment]] = [:]
    private(set) var folderPaths: IMAPFolderPaths = .defaults

    var accountId: String { credentials.accountId }

    init(credentials: IMAPCredentials) {
        self.credentials = credentials
    }

    func withConnection<T>(_ operation: (IMAPServer) async throws -> T) async throws -> T {
        let server = IMAPServer(host: credentials.host, port: Int(credentials.port))
        try await server.connect()
        try await server.login(username: credentials.email, password: credentials.password)
        defer { Task { try? await server.logout() } }
        return try await operation(server)
    }

    func testConnection() async throws {
        try await withConnection { server in
            self.folderPaths = try await IMAPFolderResolver.resolve(server: server)
        }
    }

    func getCachedBody(_ id: String) -> String? { bodyCache[id] }
    func cacheBody(_ id: String, body: String) { bodyCache[id] = body }
    func getCachedAttachments(_ id: String) -> [EmailAttachment]? { attachmentCache[id] }
    func cacheAttachments(_ id: String, attachments: [EmailAttachment]) { attachmentCache[id] = attachments }
    func clearCache() { bodyCache.removeAll(); attachmentCache.removeAll() }
}
