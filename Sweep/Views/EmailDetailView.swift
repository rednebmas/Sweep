//
//  EmailDetailView.swift
//  Sweep
//

import SwiftUI

struct EmailDetailView: View {
    let thread: EmailThread
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    Divider()
                    bodySection
                }
                .padding()
            }
            .navigationTitle("Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(thread.cleanSubject)
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.from)
                        .font(.headline)
                    Text(thread.fromEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(thread.displayDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if thread.hasAttachments {
                Label("Has attachments", systemImage: "paperclip")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(thread.snippet)
                .font(.body)

            if thread.messageCount > 1 {
                Text("\(thread.messageCount) messages in this thread")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}
