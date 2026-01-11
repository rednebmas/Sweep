//
//  EmailThread.swift
//  Sweep
//

import Foundation

struct EmailThread: Identifiable, Codable, Hashable {
    let id: String
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

    var cleanSubject: String {
        // Strip leading/trailing quotes that Gmail sometimes adds
        var cleaned = subject
        while cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 2 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

// For creating mock data during development
extension EmailThread {
    static func mock(
        id: String = UUID().uuidString,
        subject: String = "Test Subject",
        snippet: String = "This is a preview of the email content...",
        from: String = "John Doe",
        fromEmail: String = "john@example.com",
        timestamp: Date = Date(),
        hasAttachments: Bool = false,
        messageCount: Int = 1,
        unsubscribeURL: URL? = nil,
        isKept: Bool = false
    ) -> EmailThread {
        EmailThread(
            id: id,
            subject: subject,
            snippet: snippet,
            from: from,
            fromEmail: fromEmail,
            timestamp: timestamp,
            hasAttachments: hasAttachments,
            messageCount: messageCount,
            unsubscribeURL: unsubscribeURL,
            isKept: isKept
        )
    }

    static var mockList: [EmailThread] {
        [
            .mock(subject: "Your order has shipped", from: "Amazon", fromEmail: "ship-confirm@amazon.com", timestamp: Date().addingTimeInterval(-3600)),
            .mock(subject: "Weekly digest", from: "GitHub", fromEmail: "noreply@github.com", timestamp: Date().addingTimeInterval(-7200), hasAttachments: true),
            .mock(subject: "Your Uber receipt", from: "Uber", fromEmail: "uber@uber.com", timestamp: Date().addingTimeInterval(-10800)),
            .mock(subject: "Meeting tomorrow", from: "Sarah", fromEmail: "sarah@company.com", timestamp: Date().addingTimeInterval(-14400), messageCount: 3),
            .mock(subject: "Your order has been executed", from: "Robinhood", fromEmail: "noreply@robinhood.com", timestamp: Date().addingTimeInterval(-18000)),
        ]
    }
}
