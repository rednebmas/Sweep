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
        .background(thread.isKept ? Color.green.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }

    private var emailContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.from)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
            Text(thread.cleanSubject)
                .font(.system(size: 15))
                .lineLimit(1)
            Text(thread.snippet)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(snippetLines)
        }
    }

    private var metadata: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(thread.displayDate)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            if thread.hasAttachments {
                Image(systemName: "paperclip")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            if thread.messageCount > 1 {
                Text("\(thread.messageCount)")
                    .font(.system(size: 12))
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
        thread: EmailThread(
            id: "1",
            subject: "Your Amazon order has shipped!",
            snippet: "Your package with Echo Dot (5th Gen) is on its way. Track your package to see the delivery status...",
            from: "Amazon.com",
            fromEmail: "ship-confirm@amazon.com",
            timestamp: Date().addingTimeInterval(-3600),
            hasAttachments: false,
            messageCount: 1
        ),
        snippetLines: 2
    )
}

#Preview("With Attachments & Thread") {
    EmailRowView(
        thread: EmailThread(
            id: "2",
            subject: "Re: Q4 Planning Meeting - Updated projections attached",
            snippet: "Sounds good, let's sync up tomorrow at 2pm. I'll send a calendar invite shortly. Can you also bring the updated projections?",
            from: "Jennifer Martinez",
            fromEmail: "j.martinez@techcorp.com",
            timestamp: Date().addingTimeInterval(-86400),
            hasAttachments: true,
            messageCount: 4
        ),
        snippetLines: 2
    )
}

#Preview("Kept") {
    EmailRowView(
        thread: EmailThread(
            id: "3",
            subject: "Important: Action required",
            snippet: "Please review the attached document and provide your feedback by end of day Friday.",
            from: "HR Department",
            fromEmail: "hr@company.com",
            timestamp: Date(),
            hasAttachments: true,
            messageCount: 1,
            isKept: true
        ),
        snippetLines: 2
    )
}
