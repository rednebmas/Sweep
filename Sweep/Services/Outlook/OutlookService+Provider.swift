//
//  OutlookService+Provider.swift
//  Sweep
//

import Foundation

extension OutlookService: EmailProviderProtocol {
    var providerType: EmailProviderType { .outlook }
    var userEmail: String? { auth.email }
    var serverAuthCode: String? { auth.serverAuthCode }

    func signIn() async throws {
        try await auth.signIn()
    }

    func signOut() {
        auth.signOut()
        clearCache()
    }

    func refreshTokenIfNeeded() async throws {
        try await auth.refreshTokenIfNeeded()
    }

    func restorePreviousSignIn() async -> Bool {
        await auth.restorePreviousSignIn()
    }
}
