//
//  GmailService+Provider.swift
//  Sweep
//

import Foundation

extension GmailService: EmailProviderProtocol {
    var providerType: EmailProviderType { .gmail }
    var serverAuthCode: String? { auth.serverAuthCode }

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
