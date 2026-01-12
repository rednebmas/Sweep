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

        await AuthService.shared.waitForReady()

        guard gmailService.isAuthenticated else { return }

        do {
            let fetchDate = appState.getEmailFetchDate()
            threads = try await gmailService.fetchThreads(since: fetchDate)
            gmailService.prefetchBodies(for: threads.map(\.id))
            // DISABLED FOR TESTING: appState.recordAppOpen()
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

    func processNonKeptThreads() async {
        let toProcess = threads.filter { !$0.isKept }
        guard !toProcess.isEmpty else {
            threads.removeAll()
            return
        }

        let threadIds = toProcess.map(\.id)

        do {
            if appState.archiveOnBackground {
                try await gmailService.archiveAndMarkRead(threadIds)
            } else {
                try await gmailService.markReadOnly(threadIds)
            }
            let session = ArchiveSession(
                archivedThreadIds: threadIds,
                wasArchived: appState.archiveOnBackground
            )
            appState.addArchiveSession(session)
        } catch {
            self.error = error
        }

        threads.removeAll()
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

    func unsubscribe(_ thread: EmailThread) {
        guard let url = thread.unsubscribeURL else { return }
        UIApplication.shared.open(url)
    }
}
