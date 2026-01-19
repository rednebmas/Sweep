//
//  KeptEmailsSheet.swift
//  Sweep

import SwiftUI

struct KeptEmailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: EmailListViewModel
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var threads: [EmailThread] = []
    @State private var isLoading = true
    @State private var selectedThread: EmailThread?
    @State private var unkeptCompositeIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading kept emails...")
                        .frame(maxHeight: .infinity)
                } else if threads.isEmpty {
                    ContentUnavailableView(
                        "No kept emails",
                        systemImage: "checkmark.circle",
                        description: Text("Emails you keep will appear here.")
                    )
                } else {
                    threadList
                }
            }
            .navigationTitle("Kept Emails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        applyUnkeepChanges()
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedThread) { thread in
                EmailDetailView(thread: thread)
            }
            .task {
                await loadKeptThreads()
            }
        }
    }

    private var threadList: some View {
        List {
            ForEach(threads) { thread in
                EmailRowView(thread: displayThread(for: thread), snippetLines: appState.snippetLines, showAccountIndicator: accountManager.hasMultipleAccounts)
                    .listRowInsets(EdgeInsets())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if unkeptCompositeIds.contains(thread.compositeId) {
                            Button {
                                unkeptCompositeIds.remove(thread.compositeId)
                            } label: {
                                Label("Keep", systemImage: "checkmark")
                            }
                            .tint(.green)
                        } else {
                            Button {
                                unkeptCompositeIds.insert(thread.compositeId)
                            } label: {
                                Label("Unkeep", systemImage: "xmark")
                            }
                            .tint(.orange)
                        }
                    }
                    .onTapGesture {
                        selectedThread = thread
                    }
            }
        }
        .listStyle(.plain)
    }

    private func loadKeptThreads() async {
        var loadedThreads: [EmailThread] = []

        for account in accountManager.accounts {
            guard let provider = accountManager.provider(for: account.id) else { continue }
            let keptIds = KeptThreadsStore.shared.keptThreadIds(for: account.id)

            for threadId in keptIds {
                if let thread = try? await provider.fetchThreadDetail(threadId) {
                    var keptThread = thread
                    keptThread.isKept = true
                    loadedThreads.append(keptThread)
                }
            }
        }

        threads = loadedThreads.sorted { $0.timestamp > $1.timestamp }
        isLoading = false
    }

    private func displayThread(for thread: EmailThread) -> EmailThread {
        var copy = thread
        copy.isKept = !unkeptCompositeIds.contains(thread.compositeId)
        return copy
    }

    private func applyUnkeepChanges() {
        for thread in threads where unkeptCompositeIds.contains(thread.compositeId) {
            KeptThreadsStore.shared.removeKept(thread.id, accountId: thread.accountId)
            if let index = viewModel.threads.firstIndex(where: { $0.compositeId == thread.compositeId }) {
                viewModel.threads[index].isKept = false
            }
        }
    }
}
