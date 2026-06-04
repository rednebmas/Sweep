//
//  GmailService+Send.swift
//  Sweep
//

import Foundation

extension GmailService {

    func fetchReplyContext(_ threadId: String) async throws -> ReplyContext {
        let response = try await fetchFullThread(threadId)

        guard let message = response.messages?.last else {
            throw GmailError.invalidResponse
        }

        let bodyText = GmailBodyDecoder.plainText(from: message.payload)
        return makeReplyContext(from: message, threadId: threadId, selfEmail: userEmail, bodyText: bodyText)
    }

    func makeReplyContext(
        from message: MessageFullResponse,
        threadId: String,
        selfEmail: String?,
        bodyText: String
    ) -> ReplyContext {
        let headers = message.payload?.headers ?? []
        let from = EmailParticipant.parse(header("from", in: headers) ?? "")
            ?? EmailParticipant(name: "", email: "")

        return ReplyContext(
            threadId: threadId,
            messageIdHeader: header("message-id", in: headers),
            references: header("references", in: headers),
            subject: header("subject", in: headers) ?? "",
            from: from,
            to: EmailParticipant.parseList(header("to", in: headers) ?? ""),
            cc: EmailParticipant.parseList(header("cc", in: headers) ?? ""),
            date: parseDateHeader(header("date", in: headers)),
            selfEmail: selfEmail,
            originalBodyText: bodyText
        )
    }

    func sendReply(_ reply: OutgoingReply) async throws {
        guard isAuthenticated else { throw GmailError.notAuthenticated }

        let url = URL(string: "\(baseURL)/messages/send")!
        var request = try await authorizedRequest(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = SendMessageRequest(
            raw: Base64URL.encode(MIMEMessageBuilder.build(reply)),
            threadId: reply.threadId
        )
        request.httpBody = try JSONEncoder().encode(payload)

        try await performVoidRequest(request)
    }

    private func header(_ name: String, in headers: [HeaderResponse]) -> String? {
        headers.first { $0.name.lowercased() == name }?.value
    }
}
