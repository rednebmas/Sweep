//
//  ReplyComposerViewModel.swift
//  Sweep
//

import Foundation
import Combine

@MainActor
class ReplyComposerViewModel: ObservableObject {
    let thread: EmailThread
    let mode: ReplyMode

    @Published var to: [EmailParticipant] = []
    @Published var cc: [EmailParticipant] = []
    @Published var subject = ""
    @Published var body = ""
    @Published var isLoadingContext = true
    @Published var isSending = false
    @Published var loadError: String?
    @Published var toastMessage = ""
    @Published var showToast = false
    @Published var didSend = false

    private var context: ReplyContext?
    private let inboxService = UnifiedInboxService.shared

    init(thread: EmailThread, mode: ReplyMode) {
        self.thread = thread
        self.mode = mode
    }

    var canSend: Bool {
        !to.isEmpty && !isSending && !isLoadingContext
    }

    func load() async {
        isLoadingContext = true
        loadError = nil
        do {
            let context = try await inboxService.fetchReplyContext(for: thread)
            self.context = context
            let recipients = ReplyRecipientResolver.resolve(mode, context: context)
            to = recipients.to
            cc = recipients.cc
            subject = SubjectFormatter.reply(context.subject)
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingContext = false
    }

    func send() async {
        guard let context, !to.isEmpty else { return }
        isSending = true
        do {
            try await inboxService.sendReply(makeReply(context), for: thread)
            didSend = true
        } catch {
            toastMessage = error.localizedDescription
            showToast = true
        }
        isSending = false
    }

    private func makeReply(_ context: ReplyContext) -> OutgoingReply {
        OutgoingReply(
            threadId: thread.id,
            from: EmailParticipant(name: "", email: context.selfEmail ?? ""),
            to: to,
            cc: cc,
            subject: subject,
            inReplyTo: context.messageIdHeader,
            references: references(context),
            bodyPlainText: body,
            quotedOriginal: context
        )
    }

    private func references(_ context: ReplyContext) -> String? {
        guard let messageId = context.messageIdHeader else { return context.references }
        guard let existing = context.references, !existing.isEmpty else { return messageId }
        return "\(existing) \(messageId)"
    }
}
