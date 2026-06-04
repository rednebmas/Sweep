//
//  GmailService+Attachments.swift
//  Sweep
//

import Foundation

extension GmailService {

    struct PendingAttachment {
        let contentId: String
        let mimeType: String
        let attachmentId: String
    }

    func collectPendingAttachments(from payload: PayloadFullResponse?) -> [PendingAttachment] {
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

    func collectFileAttachments(from payload: PayloadFullResponse?, messageId: String) -> [EmailAttachment] {
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

    func downloadAttachment(_ attachment: EmailAttachment) async throws -> Data {
        let base64String = try await fetchAttachmentData(
            messageId: attachment.messageId,
            attachmentId: attachment.id
        )
        guard let data = Data(base64Encoded: base64String) else {
            throw GmailError.invalidResponse
        }
        return data
    }

    func fetchAttachmentData(messageId: String, attachmentId: String) async throws -> String {
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
}
