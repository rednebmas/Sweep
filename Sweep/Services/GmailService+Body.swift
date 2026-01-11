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
        print("[Body] Cache MISS for \(threadId) - fetching from network")

        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/threads/\(threadId)?format=full")!
        let request = try await authorizedRequest(url)
        let response: ThreadFullResponse = try await performRequest(request)

        guard let messages = response.messages, let firstMessage = messages.first else {
            return ""
        }

        var html = extractHTMLBody(from: firstMessage.payload)
        let pendingAttachments = collectPendingAttachments(from: firstMessage.payload)

        for attachment in pendingAttachments {
            if let data = try? await fetchAttachmentData(
                messageId: firstMessage.id,
                attachmentId: attachment.attachmentId
            ) {
                let dataURL = "data:\(attachment.mimeType);base64,\(data)"
                html = html.replacingOccurrences(of: "cid:\(attachment.contentId)", with: dataURL)
            }
        }

        cacheBody(threadId, body: html)
        return html
    }

    private struct PendingAttachment {
        let contentId: String
        let mimeType: String
        let attachmentId: String
    }

    private func collectPendingAttachments(from payload: PayloadFullResponse?) -> [PendingAttachment] {
        guard let payload = payload else { return [] }

        var attachments: [PendingAttachment] = []

        if let contentId = extractContentId(from: payload.headers),
           let mimeType = payload.mimeType,
           mimeType.hasPrefix("image/"),
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
