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
    var isBrowserOpen = false

    private let inboxService = UnifiedInboxService.shared
    private let accountManager = AccountManager.shared
    private let appState = AppState.shared
    private let keptStore = KeptThreadsStore.shared

    func loadThreads() async {
        error = nil

        if MockDataProvider.isEnabled {
            isLoading = true
            defer { isLoading = false }
            threads = MockDataProvider.mockThreads()
            return
        }

        if let cached = await ThreadCache.shared.awaitIfInFlight() {
            threads = cached
            inboxService.prefetchBodies(for: threads)
            refreshKeptCache()
            return
        }

        if threads.isEmpty, let cached = ThreadDiskCache.load() {
            threads = cached
        }

        if threads.isEmpty { isLoading = true }

        do {
            let fresh = try await BackgroundFetchService.fetchThreads()
            threads = fresh
            ThreadDiskCache.save(fresh)
            inboxService.prefetchBodies(for: threads)
            refreshKeptCache()
        } catch is CancellationError {
        } catch {
            if threads.isEmpty { self.error = error }
        }
        isLoading = false
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
        ThreadDiskCache.save(threads)
        inboxService.prefetchBodies(for: restoredThreads)
    }

    func toggleKeep(_ thread: EmailThread) {
        guard let index = threads.firstIndex(where: { $0.compositeId == thread.compositeId }) else {
            return
        }
        threads[index].isKept.toggle()

        if threads[index].isKept {
            keptStore.addKept(threads[index])
            Task { try? await inboxService.applyKeptLabel([thread]) }
        } else {
            keptStore.removeKept(thread.id, accountId: thread.accountId)
            Task { try? await inboxService.removeKeptLabel([thread]) }
        }
    }

    func unkeep(_ thread: EmailThread) {
        keptStore.removeKept(thread.id, accountId: thread.accountId)
        if let index = threads.firstIndex(where: { $0.compositeId == thread.compositeId }) {
            threads[index].isKept = false
        }
        Task { try? await inboxService.removeKeptLabel([thread]) }
    }

    func processNonKeptThreads(animated: Bool = false) async {
        if isDetailSheetOpen || isBrowserOpen {
            showSkippedProcessingToast = true
            return
        }

        let toProcess = threads.filter { !$0.isKept }
        guard !toProcess.isEmpty else { return }

        let wasArchived = appState.archiveOnBackground
        let session = SweepSession(threads: toProcess, wasArchived: wasArchived)
        let newestDate = threads.map(\.timestamp).max() ?? Date()

        appState.addArchiveSession(session)
        appState.updateEmailFetchTimestamp(newestEmailDate: newestDate)
        NotificationService.shared.clearNewEmailNotifications()

        let removal = { self.threads.removeAll { !$0.isKept } }
        if animated { withAnimation(.easeInOut(duration: 0.35)) { removal() } } else { removal() }
        ThreadDiskCache.save(threads)

        Task { [weak self] in
            do {
                if wasArchived {
                    try await UnifiedInboxService.shared.archiveThreads(toProcess)
                } else {
                    try await UnifiedInboxService.shared.markAsRead(toProcess)
                }
            } catch {
                self?.rollbackSweep(session: session, threads: toProcess, error: error)
            }
        }
    }

    private func rollbackSweep(session: SweepSession, threads restored: [EmailThread], error: Error) {
        appState.clearArchiveSession(session)
        self.threads.append(contentsOf: restored)
        self.threads.sort { $0.timestamp > $1.timestamp }
        ThreadDiskCache.save(self.threads)
        self.error = error
    }

    func blockSender(_ thread: EmailThread) async {
        do {
            try await inboxService.blockSender(thread)
            threads.removeAll { $0.compositeId == thread.compositeId }
            ThreadDiskCache.save(threads)
        } catch {
            self.error = error
        }
    }

    func markAsSpam(_ thread: EmailThread) async {
        do {
            try await inboxService.markAsSpam(thread)
            threads.removeAll { $0.compositeId == thread.compositeId }
            ThreadDiskCache.save(threads)
        } catch {
            self.error = error
        }
    }

    func unsubscribe(_ thread: EmailThread) {
        guard let url = thread.unsubscribeURL else { return }
        isBrowserOpen = true
        UIApplication.shared.open(url)
    }

    private func refreshKeptCache() {
        for thread in threads where thread.isKept {
            keptStore.updateCachedData(for: thread)
        }
    }
}
