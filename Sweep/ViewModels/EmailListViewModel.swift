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

    private let inboxService = UnifiedInboxService.shared
    private let accountManager = AccountManager.shared
    private let appState = AppState.shared
    private let keptStore = KeptThreadsStore.shared

    func loadThreads() async {
        isLoading = true
        defer { isLoading = false }

        if MockDataProvider.isEnabled {
            threads = MockDataProvider.mockThreads()
            return
        }

        await accountManager.restoreAllAccounts()

        guard accountManager.hasAnyAccount else { return }

        do {
            let fetchDate = appState.getEmailFetchDate()
            threads = try await inboxService.fetchAllThreads(since: fetchDate)
            inboxService.prefetchBodies(for: threads)
            appState.recordAppOpen()
        } catch {
            self.error = error
        }
    }

    func refresh() async {
        await loadThreads()
    }

    func reloadAfterUndo(session: SweepSession) async {
        isLoading = true
        defer { isLoading = false }

        let existingIds = Set(threads.map(\.compositeId))
        var restoredThreads: [EmailThread] = []

        for (accountId, threadIds) in session.threadsByAccount() {
            guard let provider = accountManager.provider(for: accountId) else { continue }
            for threadId in threadIds {
                let compositeId = "\(accountId):\(threadId)"
                guard !existingIds.contains(compositeId) else { continue }
                if let thread = try? await provider.fetchThreadDetail(threadId) {
                    restoredThreads.append(thread)
                }
            }
        }

        threads.append(contentsOf: restoredThreads)
        threads.sort { $0.timestamp > $1.timestamp }
        inboxService.prefetchBodies(for: restoredThreads)
    }

    func toggleKeep(_ thread: EmailThread) {
        guard let index = threads.firstIndex(where: { $0.compositeId == thread.compositeId }) else {
            return
        }
        threads[index].isKept.toggle()

        if threads[index].isKept {
            keptStore.addKept(thread.id, accountId: thread.accountId)
        } else {
            keptStore.removeKept(thread.id, accountId: thread.accountId)
        }
    }

    func processNonKeptThreads() async {
        if isDetailSheetOpen {
            showSkippedProcessingToast = true
            return
        }

        let toProcess = threads.filter { !$0.isKept }
        guard !toProcess.isEmpty else { return }

        do {
            if appState.archiveOnBackground {
                try await inboxService.archiveThreads(toProcess)
            } else {
                try await inboxService.markAsRead(toProcess)
            }
            let session = SweepSession(
                threads: toProcess,
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
            try await inboxService.blockSender(thread)
            threads.removeAll { $0.compositeId == thread.compositeId }
        } catch {
            self.error = error
        }
    }

    func markAsSpam(_ thread: EmailThread) async {
        do {
            try await inboxService.markAsSpam(thread)
            threads.removeAll { $0.compositeId == thread.compositeId }
        } catch {
            self.error = error
        }
    }

    func unsubscribe(_ thread: EmailThread) {
        guard let url = thread.unsubscribeURL else { return }
        UIApplication.shared.open(url)
    }
}
