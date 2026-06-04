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
        let response = try await fetchFullThread(threadId)

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
        var body = GmailBodyDecoder.htmlBody(from: message.payload)
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
        let escapedName = HTMLEscaper.escape(name)
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

}
