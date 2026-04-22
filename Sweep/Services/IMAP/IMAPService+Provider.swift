//
//  IMAPService+Provider.swift
//  Sweep
//

import Foundation

extension IMAPService: EmailProviderProtocol {
    var providerType: EmailProviderType { .imap }
    var userEmail: String? { credentials.email }
    var isAuthenticated: Bool { true }

    func signIn() async throws {
        try await testConnection()
        try IMAPKeychain.save(credentials)
    }

    func signOut() {
        IMAPKeychain.delete(email: credentials.email)
        clearCache()
    }

    func refreshTokenIfNeeded() async throws {}

    func restorePreviousSignIn() async -> Bool {
        IMAPKeychain.load(email: credentials.email) != nil
    }

    func blockSender(_ email: String) async throws {}
}
