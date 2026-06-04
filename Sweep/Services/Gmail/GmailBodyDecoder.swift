//
//  GmailBodyDecoder.swift
//  Sweep
//

import Foundation

enum GmailBodyDecoder {
    static func htmlBody(from payload: PayloadFullResponse?) -> String {
        guard let found = firstBody(in: payload, preferring: ["text/html", "text/plain"]) else { return "" }
        return found.mimeType == "text/plain" ? "<pre>\(found.content)</pre>" : found.content
    }

    static func plainText(from payload: PayloadFullResponse?) -> String {
        guard let found = firstBody(in: payload, preferring: ["text/plain", "text/html"]) else { return "" }
        return found.mimeType == "text/html" ? stripHTMLTags(found.content) : found.content
    }

    private static func firstBody(
        in payload: PayloadFullResponse?,
        preferring order: [String]
    ) -> (mimeType: String, content: String)? {
        guard let payload = payload else { return nil }

        if let mimeType = payload.mimeType, order.contains(mimeType), let data = payload.body?.data {
            return (mimeType, decodeBase64(data))
        }

        guard let parts = payload.parts else { return nil }

        for mimeType in order {
            if let part = parts.first(where: { $0.mimeType == mimeType }), let data = part.body?.data {
                return (mimeType, decodeBase64(data))
            }
        }

        for part in parts {
            if let found = firstBody(in: part, preferring: order) { return found }
        }

        return nil
    }

    private static func stripHTMLTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeBase64(_ encoded: String) -> String {
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
