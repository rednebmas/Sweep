//
//  ThreadCache.swift
//  Sweep

import Foundation

actor ThreadCache {
    static let shared = ThreadCache()

    private var inFlight: Task<[EmailThread], Error>?

    func fetchThreads() async throws -> [EmailThread] {
        if let existing = inFlight {
            return try await existing.value
        }
        let task = Task { @MainActor in
            try await BackgroundFetchService.fetchThreads()
        }
        inFlight = task
        do {
            let result = try await task.value
            inFlight = nil
            return result
        } catch {
            inFlight = nil
            throw error
        }
    }

    func awaitIfInFlight() async -> [EmailThread]? {
        guard let task = inFlight else { return nil }
        inFlight = nil
        return try? await task.value
    }
}
