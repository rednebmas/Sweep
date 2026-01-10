//
//  EmailDetailView.swift
//  Sweep
//

import SwiftUI

struct EmailDetailView: View {
    let thread: EmailThread
    @Environment(\.dismiss) private var dismiss
    @State private var emailBody: String?
    @State private var isLoading = true

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
            .task {
                await loadBody()
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
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let body = emailBody, !body.isEmpty {
                Text(body)
                    .font(.body)
            } else {
                Text(thread.snippet)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            if thread.messageCount > 1 {
                Text("\(thread.messageCount) messages in this thread")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    private func loadBody() async {
        do {
            emailBody = try await GmailService.shared.fetchEmailBody(thread.id)
        } catch {
            emailBody = nil
        }
        isLoading = false
    }
}
