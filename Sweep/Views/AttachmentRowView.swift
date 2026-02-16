//
//  AttachmentRowView.swift
//  Sweep

import SwiftUI

struct AttachmentRowView: View {
    let attachment: EmailAttachment
    let isDownloading: Bool
    let onTap: () async -> Void

    var body: some View {
        Button {
            Task { await onTap() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: attachment.iconName)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(attachment.displaySize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isDownloading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
