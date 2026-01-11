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
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding()
                Divider()
                bodySection
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

    @ViewBuilder
    private var bodySection: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let body = emailBody, !body.isEmpty {
            HTMLView(html: body)
        } else {
            Text(thread.snippet)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
