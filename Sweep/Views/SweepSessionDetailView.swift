//
//  SweepSessionDetailView.swift
//  Sweep
//

import SwiftUI

struct SweepSessionDetailView: View {
    let session: ArchiveSession
    let onRestore: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: EmailListViewModel
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var threads: [EmailThread] = []
    @State private var isLoading = true
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                undoButton
                threadList
            }
            .navigationTitle("Sweep Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Undo this sweep?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Undo Sweep", role: .destructive) {
                    Task { await restoreSession() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if session.wasArchived {
                    Text("This will move \(session.count) emails back to your inbox.")
                } else {
                    Text("This will mark \(session.count) emails as unread.")
                }
            }
            .task {
                await loadThreads()
            }
        }
    }

    private var undoButton: some View {
        Button {
            showingConfirmation = true
        } label: {
            Text("Undo Sweep")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .padding()
    }

    private var threadList: some View {
        Group {
            if isLoading {
                ProgressView("Loading emails...")
                    .frame(maxHeight: .infinity)
            } else if threads.isEmpty {
                ContentUnavailableView(
                    "No emails found",
                    systemImage: "envelope",
                    description: Text("These emails may have been deleted.")
                )
            } else {
                List {
                    ForEach(threads) { thread in
                        EmailRowView(thread: thread, snippetLines: appState.snippetLines)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func loadThreads() async {
        var loadedThreads: [EmailThread] = []

        for (accountId, threadIds) in session.threadsByAccount() {
            guard let provider = accountManager.provider(for: accountId) else { continue }
            for threadId in threadIds {
                if let thread = try? await provider.fetchThreadDetail(threadId) {
                    loadedThreads.append(thread)
                }
            }
        }

        threads = loadedThreads.sorted { $0.timestamp > $1.timestamp }
        isLoading = false
    }

    private func restoreSession() async {
        do {
            try await UnifiedInboxService.shared.restoreThreads(threads, wasArchived: session.wasArchived)
            appState.clearArchiveSession(session)
            await viewModel.reloadAfterUndo(session: session)
            onRestore()
            dismiss()
        } catch {
            // Handle error
        }
    }
}
