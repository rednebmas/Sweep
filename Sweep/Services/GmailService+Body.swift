//
//  GmailService+Body.swift
//  Sweep
//

import Foundation

extension GmailService {

    func prefetchBodies(for threadIds: [String]) {
        let count = min(threadIds.count, 5)
        print("[Prefetch] Starting prefetch for \(count) emails")
        Task.detached { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                for threadId in threadIds.prefix(5) {
                    group.addTask {
                        do {
                            _ = try await self?.fetchEmailBody(threadId)
                            print("[Prefetch] Fetched \(threadId)")
                        } catch {
                            print("[Prefetch] Error fetching \(threadId): \(error)")
                        }
                    }
                }
            }
            print("[Prefetch] Completed prefetch for \(count) emails")
        }
    }

    func fetchEmailBody(_ threadId: String) async throws -> String {
        if let cached = getCachedBody(threadId) {
            print("[Body] Cache HIT for \(threadId)")
            return cached
        }

        if let inFlight = getInFlightRequest(threadId) {
            print("[Body] Waiting for in-flight request for \(threadId)")
            return try await inFlight.value
        }

        print("[Body] Cache MISS for \(threadId) - fetching from network")

        let task = Task<String, Error> {
            try await fetchEmailBodyFromNetwork(threadId)
        }
        setInFlightRequest(threadId, task: task)

        do {
            let result = try await task.value
            setInFlightRequest(threadId, task: nil)
            return result
        } catch {
            setInFlightRequest(threadId, task: nil)
            throw error
        }
    }

    private func fetchEmailBodyFromNetwork(_ threadId: String) async throws -> String {
        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/threads/\(threadId)?format=full")!
        let request = try await authorizedRequest(url)
        let response: ThreadFullResponse = try await performRequest(request)

        guard let messages = response.messages, !messages.isEmpty else {
            return ""
        }

        let html: String
        if messages.count == 1 {
            html = await buildMessageBody(messages[0])
        } else {
            let divider = "<hr style=\"border:none;border-top:1px solid #38383a;margin:16px 0;\">"
            var parts: [String] = []
            for message in messages {
                let header = buildMessageHeader(message)
                let body = await buildMessageBody(message)
                parts.append(header + body)
            }
            html = parts.joined(separator: divider)
        }

        let fileAttachments = messages.flatMap { collectFileAttachments(from: $0.payload, messageId: $0.id) }
        cacheAttachments(threadId, attachments: fileAttachments)
        cacheBody(threadId, body: html)
        return html
    }

    private func buildMessageBody(_ message: MessageFullResponse) async -> String {
        var body = extractHTMLBody(from: message.payload)
        for attachment in collectPendingAttachments(from: message.payload) {
            if let data = try? await fetchAttachmentData(
                messageId: message.id,
                attachmentId: attachment.attachmentId
            ) {
                body = body.replacingOccurrences(
                    of: "cid:\(attachment.contentId)",
                    with: "data:\(attachment.mimeType);base64,\(data)"
                )
            }
        }
        return body
    }

    private func buildMessageHeader(_ message: MessageFullResponse) -> String {
        let headers = message.payload?.headers
        let fromRaw = headers?.first { $0.name.lowercased() == "from" }?.value ?? ""
        let dateRaw = headers?.first { $0.name.lowercased() == "date" }?.value
        let (name, _) = parseFromHeader(fromRaw)
        let date = parseDateHeader(dateRaw)
        let dateString = formatMessageDate(date)
        let escapedName = name
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<div style=\"margin-bottom:4px;padding:8px 0 4px;color:#8e8e93;font-size:13px;\"><strong style=\"color:#fff;\">\(escapedName)</strong> · \(dateString)</div>"
    }

    private func formatMessageDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy, h:mm a"
        }
        return formatter.string(from: date)
    }

    private struct PendingAttachment {
        let contentId: String
        let mimeType: String
        let attachmentId: String
    }

    private func collectPendingAttachments(from payload: PayloadFullResponse?) -> [PendingAttachment] {
        guard let payload = payload else { return [] }

        var attachments: [PendingAttachment] = []

        if isInlineImage(payload),
           let contentId = extractContentId(from: payload.headers),
           let mimeType = payload.mimeType,
           let attachmentId = payload.body?.attachmentId {
            attachments.append(PendingAttachment(
                contentId: contentId,
                mimeType: mimeType,
                attachmentId: attachmentId
            ))
        }

        if let parts = payload.parts {
            for part in parts {
                attachments.append(contentsOf: collectPendingAttachments(from: part))
            }
        }

        return attachments
    }

    private func collectFileAttachments(from payload: PayloadFullResponse?, messageId: String) -> [EmailAttachment] {
        guard let payload = payload else { return [] }

        var attachments: [EmailAttachment] = []

        if let filename = payload.filename, !filename.isEmpty,
           let attachmentId = payload.body?.attachmentId,
           !isInlineImage(payload) {
            attachments.append(EmailAttachment(
                id: attachmentId,
                messageId: messageId,
                filename: filename,
                mimeType: payload.mimeType ?? "application/octet-stream",
                size: payload.body?.size ?? 0
            ))
        }

        if let parts = payload.parts {
            for part in parts {
                attachments.append(contentsOf: collectFileAttachments(from: part, messageId: messageId))
            }
        }

        return attachments
    }

    func downloadAttachmentData(_ attachment: EmailAttachment) async throws -> Data {
        let base64String = try await fetchAttachmentData(
            messageId: attachment.messageId,
            attachmentId: attachment.id
        )
        guard let data = Data(base64Encoded: base64String) else {
            throw GmailError.invalidResponse
        }
        return data
    }

    private func fetchAttachmentData(messageId: String, attachmentId: String) async throws -> String {
        let url = URL(string: "\(baseURL)/messages/\(messageId)/attachments/\(attachmentId)")!
        let request = try await authorizedRequest(url)
        let response: AttachmentResponse = try await performRequest(request)

        return response.data
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
    }

    private func extractContentId(from headers: [HeaderResponse]?) -> String? {
        guard let header = headers?.first(where: { $0.name.lowercased() == "content-id" }) else {
            return nil
        }
        return header.value.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
    }

    private func extractHTMLBody(from payload: PayloadFullResponse?) -> String {
        guard let payload = payload else { return "" }

        if payload.mimeType == "text/html", let data = payload.body?.data {
            return decodeBase64(data)
        }

        if payload.mimeType == "text/plain", let data = payload.body?.data {
            return "<pre>\(decodeBase64(data))</pre>"
        }

        if let parts = payload.parts {
            if let htmlPart = parts.first(where: { $0.mimeType == "text/html" }),
               let data = htmlPart.body?.data {
                return decodeBase64(data)
            }
            if let textPart = parts.first(where: { $0.mimeType == "text/plain" }),
               let data = textPart.body?.data {
                return "<pre>\(decodeBase64(data))</pre>"
            }
            for part in parts {
                let body = extractHTMLBody(from: part)
                if !body.isEmpty { return body }
            }
        }

        return ""
    }

    private func decodeBase64(_ encoded: String) -> String {
        let base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}
