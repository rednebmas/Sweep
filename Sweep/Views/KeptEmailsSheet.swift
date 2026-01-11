//
//  KeptEmailsSheet.swift
//  Sweep
//

import SwiftUI

struct KeptEmailsSheet: View {
    let threads: [EmailThread]
    let onSelect: (EmailThread) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appState = AppState.shared
    @State private var selectedThread: EmailThread?

    var body: some View {
        NavigationStack {
            List {
                ForEach(threads) { thread in
                    EmailRowView(thread: thread, snippetLines: appState.snippetLines)
                        .listRowInsets(EdgeInsets())
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
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedThread) { thread in
                EmailDetailView(thread: thread)
            }
        }
    }
}
