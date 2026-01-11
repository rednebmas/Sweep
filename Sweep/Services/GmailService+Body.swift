//
//  GmailService+Body.swift
//  Sweep
//

import Foundation

extension GmailService {

    func fetchEmailBody(_ threadId: String) async throws -> String {
        #if DEBUG
        if MockDataProvider.useMockData {
            try? await Task.sleep(nanoseconds: 200_000_000)
            return MockDataProvider.mockEmailBody(for: threadId)
        }
        #endif

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
        let inlineAttachments = collectInlineAttachments(from: firstMessage.payload)

        for attachment in inlineAttachments {
            let dataURL = "data:\(attachment.mimeType);base64,\(attachment.data)"
            html = html.replacingOccurrences(of: "cid:\(attachment.contentId)", with: dataURL)
        }

        return html
    }

    private struct InlineAttachment {
        let contentId: String
        let mimeType: String
        let data: String
    }

    private func collectInlineAttachments(from payload: PayloadFullResponse?) -> [InlineAttachment] {
        guard let payload = payload else { return [] }

        var attachments: [InlineAttachment] = []

        if let contentId = extractContentId(from: payload.headers),
           let mimeType = payload.mimeType,
           mimeType.hasPrefix("image/"),
           let data = payload.body?.data {
            let standardBase64 = data
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            attachments.append(InlineAttachment(contentId: contentId, mimeType: mimeType, data: standardBase64))
        }

        if let parts = payload.parts {
            for part in parts {
                attachments.append(contentsOf: collectInlineAttachments(from: part))
            }
        }

        return attachments
    }

    private func extractContentId(from headers: [HeaderResponse]?) -> String? {
        guard let contentIdHeader = headers?.first(where: { $0.name.lowercased() == "content-id" }) else {
            return nil
        }
        return contentIdHeader.value.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
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
