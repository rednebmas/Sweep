//
//  EmailRowView.swift
//  Sweep
//

import SwiftUI

struct EmailRowView: View {
    let thread: EmailThread
    let snippetLines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            Text(thread.cleanSubject)
                .font(.subheadline)
                .lineLimit(1)
            if !thread.snippet.isEmpty {
                Text(thread.snippet)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(snippetLines)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(thread.isKept ? Color.green.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private var headerRow: some View {
        HStack {
            AccountIndicatorView(providerType: thread.providerType)
            Text(thread.from)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if thread.messageCount > 1 {
                Text("\(thread.messageCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            if thread.hasAttachments {
                Image(systemName: "paperclip")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(thread.displayDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
