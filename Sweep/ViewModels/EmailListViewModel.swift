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
    @Published var showSkippedProcessingToast = false

    var isDetailSheetOpen = false

    private let gmailService = GmailService.shared
    private let appState = AppState.shared
    private let keptStore = KeptThreadsStore.shared

    func loadThreads() async {
        isLoading = true
        defer { isLoading = false }

        await AuthService.shared.waitForReady()

        guard gmailService.isAuthenticated else { return }

        do {
            let fetchDate = appState.getEmailFetchDate()
            threads = try await gmailService.fetchThreads(since: fetchDate)
            gmailService.prefetchBodies(for: threads.map(\.id))
            appState.recordAppOpen()
        } catch {
            self.error = error
        }
    }

    func refresh() async {
        await loadThreads()
    }

    func reloadAfterUndo(session: SweepSession) async {
        appState.lastOpenedTimestamp = session.timestamp
        isLoading = true
        defer { isLoading = false }

        do {
            threads = try await gmailService.fetchThreads(since: session.timestamp)
            gmailService.prefetchBodies(for: threads.map(\.id))
        } catch {
            self.error = error
        }
    }

    func toggleKeep(_ thread: EmailThread) {
        guard let index = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        threads[index].isKept.toggle()

        if threads[index].isKept {
            keptStore.addKept(thread.id)
        } else {
            keptStore.removeKept(thread.id)
        }
    }

    func processNonKeptThreads() async {
        if isDetailSheetOpen {
            showSkippedProcessingToast = true
            return
        }

        let toProcess = threads.filter { !$0.isKept }
        guard !toProcess.isEmpty else { return }

        let threadIds = toProcess.map(\.id)

        do {
            if appState.archiveOnBackground {
                try await gmailService.archiveAndMarkRead(threadIds)
            } else {
                try await gmailService.markReadOnly(threadIds)
            }
            let session = SweepSession(
                threadIds: threadIds,
                wasArchived: appState.archiveOnBackground
            )
            appState.addArchiveSession(session)
        } catch {
            self.error = error
        }

        threads.removeAll { !$0.isKept }
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
