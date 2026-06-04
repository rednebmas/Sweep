//
//  MIMEMessageBuilder.swift
//  Sweep
//

import Foundation

enum MIMEMessageBuilder {
    static func build(_ reply: OutgoingReply, sentAt: Date = Date()) -> Data {
        let boundary = "----=_Sweep_\(UUID().uuidString)"
        let message = headers(reply, boundary: boundary, sentAt: sentAt) + "\r\n" + body(reply, boundary: boundary)
        return Data(message.utf8)
    }

    private static func headers(_ reply: OutgoingReply, boundary: String, sentAt: Date) -> String {
        var lines: [String] = [
            "From: \(MIMEHeaderEncoder.encodeAddress(reply.from))",
            "To: \(MIMEHeaderEncoder.encodeAddressList(reply.to))"
        ]
        if !reply.cc.isEmpty {
            lines.append("Cc: \(MIMEHeaderEncoder.encodeAddressList(reply.cc))")
        }
        lines.append("Subject: \(MIMEHeaderEncoder.encode(reply.subject))")
        if let inReplyTo = reply.inReplyTo {
            lines.append("In-Reply-To: \(inReplyTo)")
        }
        if let references = reply.references {
            lines.append("References: \(references)")
        }
        lines.append("Date: \(rfc822Date(sentAt))")
        lines.append("MIME-Version: 1.0")
        lines.append("Content-Type: multipart/alternative; boundary=\"\(boundary)\"")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func body(_ reply: OutgoingReply, boundary: String) -> String {
        let plain = EmailQuoteFormatter.plainText(reply: reply.bodyPlainText, context: reply.quotedOriginal)
        let html = EmailQuoteFormatter.html(reply: reply.bodyPlainText, context: reply.quotedOriginal)
        return part(contentType: "text/plain; charset=\"UTF-8\"", body: plain, boundary: boundary)
            + part(contentType: "text/html; charset=\"UTF-8\"", body: html, boundary: boundary)
            + "--\(boundary)--\r\n"
    }

    private static func part(contentType: String, body: String, boundary: String) -> String {
        let normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n")
        return "--\(boundary)\r\n"
            + "Content-Type: \(contentType)\r\n"
            + "Content-Transfer-Encoding: 8bit\r\n"
            + "\r\n"
            + normalized
            + "\r\n"
    }

    private static func rfc822Date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: date)
    }
}
