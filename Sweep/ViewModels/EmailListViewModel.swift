//
//  EmailListViewModel.swift
//  Sweep
//

import SwiftUI
import Combine

@MainActor
class EmailListViewModel: ObservableObject {
    @Published var threads: [EmailThread] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let gmailService = GmailService.shared
    private let appState = AppState.shared

    func loadThreads() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchDate = appState.getEmailFetchDate()
            threads = try await gmailService.fetchThreads(since: fetchDate)
            appState.recordAppOpen()
        } catch {
            self.error = error
        }
    }

    func refresh() async {
        await loadThreads()
    }

    func toggleKeep(_ thread: EmailThread) {
        guard let index = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        threads[index].isKept.toggle()
    }

    func archiveNonKeptThreads() async {
        let toArchive = threads.filter { !$0.isKept }
        guard !toArchive.isEmpty else { return }

        let threadIds = toArchive.map(\.id)

        do {
            try await gmailService.archiveAndMarkRead(threadIds)
            let session = ArchiveSession(archivedThreadIds: threadIds)
            appState.addArchiveSession(session)
            threads.removeAll { !$0.isKept }
        } catch {
            self.error = error
        }
    }

    func blockSender(_ thread: EmailThread) async {
        do {
            try await gmailService.blockSender(thread.fromEmail)
            threads.removeAll { $0.id == thread.id }
        } catch {
            self.error = error
        }
    }

    func markAsSpam(_ thread: EmailThread) async {
        do {
            try await gmailService.markAsSpam(thread.id)
            threads.removeAll { $0.id == thread.id }
        } catch {
            self.error = error
        }
    }

    func unsubscribe(_ thread: EmailThread) async {
        do {
            try await gmailService.unsubscribe(thread.id)
            threads.removeAll { $0.id == thread.id }
        } catch {
            self.error = error
        }
    }
}
