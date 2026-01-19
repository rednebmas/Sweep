//
//  EmailThread.swift
//  Sweep
//

import Foundation

struct EmailThread: Identifiable, Codable, Hashable {
    let id: String
    let accountId: String
    let providerType: EmailProviderType
    let subject: String
    let snippet: String
    let from: String
    let fromEmail: String
    let timestamp: Date
    let hasAttachments: Bool
    let messageCount: Int
    let unsubscribeURL: URL?
    var isKept: Bool = false

    // For display
    var displayDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: timestamp)
        }
    }

    var senderInitial: String {
        from.first.map(String.init) ?? "?"
    }

    var compositeId: String {
        "\(accountId):\(id)"
    }

    var cleanSubject: String {
        // Strip leading/trailing quotes that Gmail sometimes adds
        var cleaned = subject
        while cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 2 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
