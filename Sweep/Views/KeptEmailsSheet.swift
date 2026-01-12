//
//  KeptEmailsSheet.swift
//  Sweep

import SwiftUI

struct KeptEmailsSheet: View {
    let onSelect: (EmailThread) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: EmailListViewModel
    @ObservedObject private var appState = AppState.shared
    @State private var threads: [EmailThread] = []
    @State private var isLoading = true
    @State private var selectedThread: EmailThread?
    @State private var unkeptThreadIds: Set<String> = []

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
                EmailRowView(thread: displayThread(for: thread), snippetLines: appState.snippetLines)
                    .listRowInsets(EdgeInsets())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if unkeptThreadIds.contains(thread.id) {
                            Button {
                                unkeptThreadIds.remove(thread.id)
                            } label: {
                                Label("Keep", systemImage: "checkmark")
                            }
                            .tint(.green)
                        } else {
                            Button {
                                unkeptThreadIds.insert(thread.id)
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
        let keptIds = KeptThreadsStore.shared.keptThreadIds()
        var loadedThreads: [EmailThread] = []

        for threadId in keptIds {
            if let thread = try? await GmailService.shared.fetchThreadDetail(threadId) {
                var keptThread = thread
                keptThread.isKept = true
                loadedThreads.append(keptThread)
            }
        }

        threads = loadedThreads.sorted { $0.timestamp > $1.timestamp }
        isLoading = false
    }

    private func displayThread(for thread: EmailThread) -> EmailThread {
        var copy = thread
        copy.isKept = !unkeptThreadIds.contains(thread.id)
        return copy
    }

    private func applyUnkeepChanges() {
        for threadId in unkeptThreadIds {
            KeptThreadsStore.shared.removeKept(threadId)
            if let index = viewModel.threads.firstIndex(where: { $0.id == threadId }) {
                viewModel.threads[index].isKept = false
            }
        }
    }
}
