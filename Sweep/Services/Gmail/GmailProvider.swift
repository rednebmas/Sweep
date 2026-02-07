//
//  GmailProvider.swift
//  Sweep

import Foundation

@MainActor
class GmailProvider: EmailProviderProtocol {
    let providerType: EmailProviderType = .gmail

    private let auth: AuthService
    private let service: GmailService

    var accountId: String { auth.accountId }
    var userEmail: String? { auth.userEmail }
    var isAuthenticated: Bool { auth.isAuthenticated }
    var serverAuthCode: String? { auth.serverAuthCode }

    init() {
        self.auth = AuthService()
        self.service = GmailService(auth: auth)
    }

    func signIn() async throws {
        try await auth.signIn()
    }

    func signOut() {
        auth.signOut()
        service.clearCache()
    }

    func refreshTokenIfNeeded() async throws {
        try await auth.refreshTokenIfNeeded()
    }

    func restorePreviousSignIn() async -> Bool {
        await auth.restorePreviousSignIn()
    }

    func fetchThreads(since date: Date) async throws -> [EmailThread] {
        try await service.fetchThreads(since: date)
    }

    func fetchThreadDetail(_ threadId: String) async throws -> EmailThread? {
        try await service.fetchThreadDetail(threadId)
    }

    func fetchEmailBody(_ threadId: String) async throws -> String {
        try await service.fetchEmailBody(threadId)
    }

    func prefetchBodies(for threadIds: [String]) {
        service.prefetchBodies(for: threadIds)
    }

    func archiveThreads(_ threadIds: [String]) async throws {
        try await service.archiveThreads(threadIds)
    }

    func markAsRead(_ threadIds: [String]) async throws {
        try await service.markAsRead(threadIds)
    }

    func archiveAndMarkRead(_ threadIds: [String]) async throws {
        try await service.archiveAndMarkRead(threadIds)
    }

    func markReadOnly(_ threadIds: [String]) async throws {
        try await service.markReadOnly(threadIds)
    }

    func markAsSpam(_ threadId: String) async throws {
        try await service.markAsSpam(threadId)
    }

    func blockSender(_ email: String) async throws {
        try await service.blockSender(email)
    }

    func restoreThreads(_ threadIds: [String], wasArchived: Bool) async throws {
        try await service.restoreThreads(threadIds, wasArchived: wasArchived)
    }

    func applyKeptLabel(_ threadIds: [String]) async throws {
        try await service.applyKeptLabel(threadIds)
    }

    func removeKeptLabel(_ threadIds: [String]) async throws {
        try await service.removeKeptLabel(threadIds)
    }
}
