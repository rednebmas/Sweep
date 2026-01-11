//
//  SweepSessionDetailView.swift
//  Sweep
//

import SwiftUI

struct SweepSessionDetailView: View {
    let session: ArchiveSession
    let onRestore: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appState = AppState.shared
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
                Text("This will move \(session.archivedCount) emails back to your inbox.")
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

        for threadId in session.archivedThreadIds {
            if let thread = try? await GmailService.shared.fetchThreadDetail(threadId) {
                loadedThreads.append(thread)
            }
        }

        threads = loadedThreads.sorted { $0.timestamp > $1.timestamp }
        isLoading = false
    }

    private func restoreSession() async {
        do {
            try await GmailService.shared.restoreThreads(session.archivedThreadIds)
            appState.clearArchiveSession(session)
            onRestore()
            dismiss()
        } catch {
            // TODO: Show error
        }
    }
}
