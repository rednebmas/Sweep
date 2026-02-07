//
//  EmailProviderProtocol.swift
//  Sweep

import Foundation

protocol EmailProviderProtocol: AnyObject {
    var providerType: EmailProviderType { get }
    var accountId: String { get }
    var userEmail: String? { get }
    var isAuthenticated: Bool { get }

    func signIn() async throws
    func signOut()
    func refreshTokenIfNeeded() async throws
    func restorePreviousSignIn() async -> Bool

    func fetchThreads(since date: Date) async throws -> [EmailThread]
    func fetchThreadDetail(_ threadId: String) async throws -> EmailThread?
    func fetchEmailBody(_ threadId: String) async throws -> String
    func prefetchBodies(for threadIds: [String])

    func archiveThreads(_ threadIds: [String]) async throws
    func markAsRead(_ threadIds: [String]) async throws
    func archiveAndMarkRead(_ threadIds: [String]) async throws
    func markReadOnly(_ threadIds: [String]) async throws
    func markAsSpam(_ threadId: String) async throws
    func blockSender(_ email: String) async throws
    func restoreThreads(_ threadIds: [String], wasArchived: Bool) async throws
    func applyKeptLabel(_ threadIds: [String]) async throws
    func removeKeptLabel(_ threadIds: [String]) async throws
}

extension EmailProviderProtocol {
    func applyKeptLabel(_ threadIds: [String]) async throws {}
    func removeKeptLabel(_ threadIds: [String]) async throws {}
}
