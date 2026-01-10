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
