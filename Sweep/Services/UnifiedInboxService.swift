//
//  UnifiedInboxService.swift
//  Sweep

import Foundation
import Combine

enum EmailError: Error, LocalizedError {
    case providerNotFound
    case noEnabledAccounts

    var errorDescription: String? {
        switch self {
        case .providerNotFound: return "Email provider not found"
        case .noEnabledAccounts: return "No enabled accounts"
        }
    }
}

class UnifiedInboxService: ObservableObject {
    static let shared = UnifiedInboxService()

    private let accountManager = AccountManager.shared

    private init() {}

    func fetchAllThreads(since date: Date) async throws -> [EmailThread] {
        let enabledAccounts = accountManager.enabledAccounts
        guard !enabledAccounts.isEmpty else {
            return []
        }

        return try await withThrowingTaskGroup(of: [EmailThread].self) { group in
            for account in enabledAccounts {
                guard let provider = accountManager.provider(for: account.id) else { continue }
                group.addTask {
                    try await provider.fetchThreads(since: date)
                }
            }

            var all: [EmailThread] = []
            for try await threads in group {
                all.append(contentsOf: threads)
            }
            return all.sorted { $0.timestamp > $1.timestamp }
        }
    }

    func archiveThreads(_ threads: [EmailThread]) async throws {
        let grouped = Dictionary(grouping: threads, by: \.accountId)
        for (accountId, accountThreads) in grouped {
            guard let provider = accountManager.provider(for: accountId) else { continue }
            try await provider.archiveAndMarkRead(accountThreads.map(\.id))
        }
    }

    func markAsRead(_ threads: [EmailThread]) async throws {
        let grouped = Dictionary(grouping: threads, by: \.accountId)
        for (accountId, accountThreads) in grouped {
            guard let provider = accountManager.provider(for: accountId) else { continue }
            try await provider.markAsRead(accountThreads.map(\.id))
        }
    }

    func restoreThreads(_ threads: [EmailThread], wasArchived: Bool) async throws {
        let grouped = Dictionary(grouping: threads, by: \.accountId)
        for (accountId, accountThreads) in grouped {
            guard let provider = accountManager.provider(for: accountId) else { continue }
            try await provider.restoreThreads(accountThreads.map(\.id), wasArchived: wasArchived)
        }
    }

    func fetchEmailBody(for thread: EmailThread) async throws -> String {
        guard let provider = accountManager.provider(for: thread.accountId) else {
            throw EmailError.providerNotFound
        }
        return try await provider.fetchEmailBody(thread.id)
    }

    func prefetchBodies(for threads: [EmailThread]) {
        let grouped = Dictionary(grouping: threads, by: \.accountId)
        for (accountId, accountThreads) in grouped {
            guard let provider = accountManager.provider(for: accountId) else { continue }
            provider.prefetchBodies(for: accountThreads.map(\.id))
        }
    }

    func markAsSpam(_ thread: EmailThread) async throws {
        guard let provider = accountManager.provider(for: thread.accountId) else {
            throw EmailError.providerNotFound
        }
        try await provider.markAsSpam(thread.id)
    }

    func blockSender(_ thread: EmailThread) async throws {
        guard let provider = accountManager.provider(for: thread.accountId) else {
            throw EmailError.providerNotFound
        }
        try await provider.blockSender(thread.fromEmail)
    }
}
