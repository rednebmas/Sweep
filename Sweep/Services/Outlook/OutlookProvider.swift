//
//  OutlookProvider.swift
//  Sweep

import Foundation

class OutlookProvider: EmailProviderProtocol {
    let providerType: EmailProviderType = .outlook

    private let auth: OutlookAuth
    private let service: OutlookService

    var accountId: String { auth.accountId }
    var userEmail: String? { auth.email }
    var isAuthenticated: Bool { auth.isAuthenticated }
    var serverAuthCode: String? { auth.serverAuthCode }

    init() {
        self.auth = OutlookAuth()
        self.service = OutlookService(auth: auth)
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
        try await service.archiveMessages(threadIds)
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
        try await service.restoreMessages(threadIds, wasArchived: wasArchived)
    }
}
