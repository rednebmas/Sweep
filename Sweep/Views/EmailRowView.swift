//
//  EmailRowView.swift
//  Sweep
//

import SwiftUI

struct EmailRowView: View {
    let thread: EmailThread
    let snippetLines: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            emailContent
            Spacer()
            metadata
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(thread.isKept ? Color.green.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private var emailContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.from)
                .font(.headline)
                .lineLimit(1)
            Text(thread.cleanSubject)
                .font(.subheadline)
                .lineLimit(1)
            Text(thread.snippet)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(snippetLines)
        }
    }

    private var metadata: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(thread.displayDate)
                .font(.caption)
                .foregroundColor(.secondary)
            if thread.hasAttachments {
                Image(systemName: "paperclip")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if thread.messageCount > 1 {
                Text("\(thread.messageCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
}

#Preview("Standard") {
    EmailRowView(
        thread: .mock(
            subject: "Your Amazon order has shipped!",
            snippet: "Your package with Echo Dot (5th Gen) is on its way...",
            from: "Amazon.com",
            fromEmail: "ship-confirm@amazon.com"
        ),
        snippetLines: 2
    )
}

#Preview("With Attachments & Thread") {
    EmailRowView(
        thread: .mock(
            subject: "Re: Q4 Planning Meeting",
            snippet: "Sounds good, let's sync up tomorrow at 2pm...",
            from: "Jennifer Martinez",
            hasAttachments: true,
            messageCount: 4
        ),
        snippetLines: 2
    )
}

#Preview("Kept") {
    EmailRowView(
        thread: .mock(
            subject: "Important: Action required",
            snippet: "Please review the attached document...",
            from: "HR Department",
            hasAttachments: true,
            isKept: true
        ),
        snippetLines: 2
    )
}
