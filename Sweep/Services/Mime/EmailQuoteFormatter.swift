//
//  EmailQuoteFormatter.swift
//  Sweep
//

import Foundation

enum EmailQuoteFormatter {
    static func attribution(_ context: ReplyContext) -> String {
        "On \(formattedDate(context.date)), \(context.from.displayName) wrote:"
    }

    static func plainText(reply: String, context: ReplyContext) -> String {
        let quoted = context.originalBodyText
            .components(separatedBy: "\n")
            .map { "> \($0)" }
            .joined(separator: "\n")
        return "\(reply)\n\n\(attribution(context))\n\(quoted)"
    }

    static func html(reply: String, context: ReplyContext) -> String {
        let attribution = HTMLEscaper.escape(self.attribution(context))
        let quoteStyle = "margin:0 0 0 8px;padding-left:12px;border-left:2px solid #ccc;color:#666;"
        return "<div>\(htmlParagraph(reply))</div>"
            + "<div style=\"color:#8e8e93;margin-top:12px;\">\(attribution)</div>"
            + "<blockquote style=\"\(quoteStyle)\">\(htmlParagraph(context.originalBodyText))</blockquote>"
    }

    private static func htmlParagraph(_ text: String) -> String {
        HTMLEscaper.escape(text).replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}
