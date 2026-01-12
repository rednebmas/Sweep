//
//  KeptEmailsSheet.swift
//  Sweep

import SwiftUI

struct KeptEmailsSheet: View {
    let threads: [EmailThread]
    let onSelect: (EmailThread) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: EmailListViewModel
    @ObservedObject private var appState = AppState.shared
    @State private var selectedThread: EmailThread?
    @State private var unkeptThreadIds: Set<String> = []

    var body: some View {
        NavigationStack {
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
        }
    }

    private func displayThread(for thread: EmailThread) -> EmailThread {
        var copy = thread
        copy.isKept = !unkeptThreadIds.contains(thread.id)
        return copy
    }

    private func applyUnkeepChanges() {
        for threadId in unkeptThreadIds {
            if let thread = threads.first(where: { $0.id == threadId }) {
                viewModel.toggleKeep(thread)
            }
        }
    }
}
