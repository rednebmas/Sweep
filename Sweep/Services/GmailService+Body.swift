//
//  GmailService+Body.swift
//  Sweep
//

import Foundation

extension GmailService {

    func fetchEmailBody(_ threadId: String) async throws -> String {
        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/threads/\(threadId)?format=full")!
        let request = try await authorizedRequest(url)

        let response: ThreadFullResponse = try await performRequest(request)

        guard let messages = response.messages, let firstMessage = messages.first else {
            return ""
        }

        return extractBody(from: firstMessage.payload)
    }

    func extractBody(from payload: PayloadFullResponse?) -> String {
        guard let payload = payload else { return "" }

        if payload.mimeType == "text/plain", let data = payload.body?.data {
            return decodeBase64(data)
        }

        if payload.mimeType == "text/html", let data = payload.body?.data {
            return stripHTML(decodeBase64(data))
        }

        if let parts = payload.parts {
            if let textPart = parts.first(where: { $0.mimeType == "text/plain" }),
               let data = textPart.body?.data {
                return decodeBase64(data)
            }
            if let htmlPart = parts.first(where: { $0.mimeType == "text/html" }),
               let data = htmlPart.body?.data {
                return stripHTML(decodeBase64(data))
            }
            for part in parts {
                let body = extractBody(from: part)
                if !body.isEmpty { return body }
            }
        }

        return ""
    }

    func decodeBase64(_ encoded: String) -> String {
        let base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    func stripHTML(_ html: String) -> String {
        var text = html
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)

        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text.removeSubrange(range)
        }

        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.joined(separator: "\n\n")
    }
}
