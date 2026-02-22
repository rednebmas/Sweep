//
//  IMAPService+Fetch.swift
//  Sweep

import Foundation
import SwiftMail

extension IMAPService {
    func fetchThreads(since date: Date) async throws -> [EmailThread] {
        try await withConnection { server in
            let selection = try await server.selectMailbox(self.folderPaths.inbox)
            guard selection.messageCount > 0 else { return [] }

            guard let latest = selection.latest(200) else { return [] }
            let infos = try await server.fetchMessageInfosBulk(using: latest)

            return infos
                .filter { !$0.flags.contains(.seen) && ($0.date ?? .distantPast) >= date }
                .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                .prefix(100)
                .map { self.mapToThread($0) }
        }
    }

    func fetchThreadDetail(_ uid: String) async throws -> EmailThread? {
        guard let uidValue = parseUID(uid) else { return nil }
        return try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            guard let info = try await server.fetchMessageInfo(for: uidValue) else { return nil }
            return self.mapToThread(info)
        }
    }

    func fetchEmailBody(_ uid: String) async throws -> String {
        if let cached = getCachedBody(uid) { return cached }

        guard let uidValue = parseUID(uid) else {
            throw IMAPError.fetchFailed("Invalid UID: \(uid)")
        }

        let body: String = try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            guard let info = try await server.fetchMessageInfo(for: uidValue) else {
                throw IMAPError.fetchFailed("Message not found")
            }
            let message = try await server.fetchMessage(from: info)
            return message.htmlBody ?? message.textBody ?? ""
        }

        cacheBody(uid, body: body)
        return body
    }

    func fetchAttachments(_ uid: String) async throws -> [EmailAttachment] {
        if let cached = getCachedAttachments(uid) { return cached }

        guard let uidValue = parseUID(uid) else { return [] }

        let attachments: [EmailAttachment] = try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            guard let info = try await server.fetchMessageInfo(for: uidValue) else { return [] }
            let message = try await server.fetchMessage(from: info)
            return message.attachments.enumerated().map { index, part in
                EmailAttachment(
                    id: "\(uid)_\(index)",
                    messageId: uid,
                    filename: part.suggestedFilename,
                    mimeType: part.contentType ?? "application/octet-stream",
                    size: part.data?.count ?? 0
                )
            }
        }

        cacheAttachments(uid, attachments: attachments)
        return attachments
    }

    func downloadAttachmentData(_ attachment: EmailAttachment) async throws -> Data {
        guard let uidValue = parseUID(attachment.messageId) else {
            throw IMAPError.fetchFailed("Invalid UID")
        }

        return try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            guard let info = try await server.fetchMessageInfo(for: uidValue) else {
                throw IMAPError.fetchFailed("Message not found")
            }
            let message = try await server.fetchMessage(from: info)
            guard let part = message.attachments.first(where: { $0.suggestedFilename == attachment.filename }),
                  let data = part.decodedData() else {
                throw IMAPError.fetchFailed("Attachment not found")
            }
            return data
        }
    }

    func prefetchBodies(for uids: [String]) {
        let count = min(uids.count, 5)
        Task.detached { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                for uid in uids.prefix(5) {
                    group.addTask { _ = try? await self?.fetchEmailBody(uid) }
                }
            }
            print("[IMAP Prefetch] Completed prefetch for \(count) emails")
        }
    }

    private func mapToThread(_ info: MessageInfo) -> EmailThread {
        let uidString = info.uid.map { String($0.value) } ?? String(info.sequenceNumber.value)
        let hasAttach = info.parts.contains { $0.disposition == "attachment" }

        return EmailThread(
            id: uidString,
            accountId: accountId,
            providerType: .imap,
            subject: info.subject ?? "(No Subject)",
            snippet: "",
            from: info.from ?? "Unknown",
            fromEmail: info.from ?? "",
            timestamp: info.date ?? Date(),
            hasAttachments: hasAttach,
            messageCount: 1,
            unsubscribeURL: nil,
            isKept: KeptThreadsStore.shared.isKept(uidString, accountId: accountId)
        )
    }

    private func parseUID(_ string: String) -> UID? {
        guard let raw = UInt32(string) else { return nil }
        return UID(raw)
    }
}
