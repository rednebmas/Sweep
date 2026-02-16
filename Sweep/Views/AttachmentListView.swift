//
//  AttachmentListView.swift
//  Sweep

import QuickLook
import SwiftUI

struct AttachmentListView: View {
    let attachments: [EmailAttachment]
    let thread: EmailThread
    @State private var downloadingId: String?
    @State private var previewURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(attachments) { attachment in
                AttachmentRowView(
                    attachment: attachment,
                    isDownloading: downloadingId == attachment.id,
                    onTap: { await download(attachment) }
                )
            }
        }
        .quickLookPreview($previewURL)
    }

    private func download(_ attachment: EmailAttachment) async {
        downloadingId = attachment.id
        defer { downloadingId = nil }

        do {
            let data = try await UnifiedInboxService.shared.downloadAttachment(attachment, for: thread)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.filename)
            try data.write(to: tempURL)
            previewURL = tempURL
        } catch {
            print("Failed to download attachment: \(error)")
        }
    }
}
