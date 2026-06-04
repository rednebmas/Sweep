//
//  EmailDetailView.swift
//  Sweep
//

import SwiftUI

struct EmailDetailView: View {
    let thread: EmailThread
    @Environment(\.dismiss) private var dismiss
    @State private var emailBody: String?
    @State private var attachments: [EmailAttachment] = []
    @State private var isLoading = true
    @State private var replyMode: ReplyMode?
    @State private var showSentToast = false

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
                ToolbarItem(placement: .topBarLeading) {
                    if UnifiedInboxService.shared.supportsReply(for: thread) {
                        replyMenu
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadBody()
            }
            .sheet(item: $replyMode) { mode in
                ReplyComposerView(viewModel: ReplyComposerViewModel(thread: thread, mode: mode)) {
                    showSentToast = true
                }
            }
            .toast(isPresented: $showSentToast, message: "Reply sent")
        }
    }

    private var replyMenu: some View {
        Menu {
            Button {
                replyMode = .reply
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            Button {
                replyMode = .replyAll
            } label: {
                Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
            }
        } label: {
            Image(systemName: "arrowshape.turn.up.left")
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

            if !attachments.isEmpty {
                AttachmentListView(attachments: attachments, thread: thread)
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
                .padding([.horizontal, .top])
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
            emailBody = try await UnifiedInboxService.shared.fetchEmailBody(for: thread)
            attachments = (try? await UnifiedInboxService.shared.fetchAttachments(for: thread)) ?? []
        } catch {
            emailBody = nil
        }
        isLoading = false
    }
}
