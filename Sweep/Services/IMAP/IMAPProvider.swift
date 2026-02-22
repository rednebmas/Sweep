//
//  IMAPProvider.swift
//  Sweep

import Foundation

class IMAPProvider: EmailProviderProtocol {
    let providerType: EmailProviderType = .imap

    private let service: IMAPService
    private let email: String

    var accountId: String { service.accountId }
    var userEmail: String? { email }
    var isAuthenticated: Bool { true }

    init(credentials: IMAPCredentials) {
        self.email = credentials.email
        self.service = IMAPService(credentials: credentials)
    }

    func signIn() async throws {
        try await service.testConnection()
        try IMAPKeychain.save(service.credentials)
    }

    func signOut() {
        IMAPKeychain.delete(email: email)
        service.clearCache()
    }

    func refreshTokenIfNeeded() async throws {}

    func restorePreviousSignIn() async -> Bool {
        IMAPKeychain.load(email: email) != nil
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
        // Not possible via IMAP
    }

    func restoreThreads(_ threadIds: [String], wasArchived: Bool) async throws {
        try await service.restoreMessages(threadIds, wasArchived: wasArchived)
    }

    func fetchAttachments(_ threadId: String) async throws -> [EmailAttachment] {
        try await service.fetchAttachments(threadId)
    }

    func downloadAttachment(_ attachment: EmailAttachment) async throws -> Data {
        try await service.downloadAttachmentData(attachment)
    }
}
