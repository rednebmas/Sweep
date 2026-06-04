//
//  GmailService+Provider.swift
//  Sweep
//

import Foundation

extension GmailService: EmailProviderProtocol {
    var providerType: EmailProviderType { .gmail }
    var serverAuthCode: String? { auth.serverAuthCode }
    var supportsReply: Bool { true }

    func refreshTokenIfNeeded() async throws {
        try await auth.refreshTokenIfNeeded()
    }

    func restorePreviousSignIn() async -> Bool {
        await auth.restorePreviousSignIn()
    }

    func fetchAttachments(_ threadId: String) async throws -> [EmailAttachment] {
        getCachedAttachments(threadId)
    }
}
