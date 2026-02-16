//
//  BackgroundFetchService.swift
//  Sweep

import Foundation

enum BackgroundFetchService {
    @MainActor
    static func fetchThreads() async throws -> [EmailThread] {
        await AccountManager.shared.restoreAllAccounts()
        guard AccountManager.shared.hasAnyAccount else { return [] }
        let fetchDate = AppState.shared.getEmailFetchDate()
        return try await UnifiedInboxService.shared.fetchAllThreads(since: fetchDate)
    }
}
