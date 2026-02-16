//
//  OutlookService+Fetch.swift
//  Sweep

import Foundation

extension OutlookService {

    func fetchThreads(since date: Date) async throws -> [EmailThread] {
        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateString = formatter.string(from: date)

        let filter = "receivedDateTime ge \(dateString) and isRead eq false"
        let encodedFilter = filter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filter
        let select = "id,conversationId,subject,bodyPreview,from,receivedDateTime,hasAttachments,isRead"

        let url = URL(string: "\(baseURL)/mailFolders/inbox/messages?$filter=\(encodedFilter)&$select=\(select)&$top=100&$orderby=receivedDateTime desc")!

        let request = try await authorizedRequest(url)
        let response: OutlookMessageListResponse = try await performRequest(request)

        guard let messages = response.value else {
            return []
        }

        return messages.map { message in
            EmailThread(
                id: message.id,
                accountId: accountId,
                providerType: .outlook,
                subject: message.subject ?? "(No Subject)",
                snippet: message.bodyPreview ?? "",
                from: message.from?.emailAddress?.name ?? message.from?.emailAddress?.address ?? "Unknown",
                fromEmail: message.from?.emailAddress?.address ?? "",
                timestamp: message.parsedDate,
                hasAttachments: message.hasAttachments ?? false,
                messageCount: 1,
                unsubscribeURL: nil,
                isKept: KeptThreadsStore.shared.isKept(message.id, accountId: accountId)
            )
        }
    }

    func fetchThreadDetail(_ messageId: String) async throws -> EmailThread? {
        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let select = "id,conversationId,subject,bodyPreview,from,receivedDateTime,hasAttachments,isRead"
        let url = URL(string: "\(baseURL)/messages/\(messageId)?$select=\(select)")!

        let request = try await authorizedRequest(url)
        let message: OutlookMessage = try await performRequest(request)

        return EmailThread(
            id: message.id,
            accountId: accountId,
            providerType: .outlook,
            subject: message.subject ?? "(No Subject)",
            snippet: message.bodyPreview ?? "",
            from: message.from?.emailAddress?.name ?? message.from?.emailAddress?.address ?? "Unknown",
            fromEmail: message.from?.emailAddress?.address ?? "",
            timestamp: message.parsedDate,
            hasAttachments: message.hasAttachments ?? false,
            messageCount: 1,
            unsubscribeURL: nil,
            isKept: KeptThreadsStore.shared.isKept(message.id, accountId: accountId)
        )
    }

    func fetchEmailBody(_ messageId: String) async throws -> String {
        if let cached = getCachedBody(messageId) {
            return cached
        }

        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/messages/\(messageId)?$select=body")!
        let request = try await authorizedRequest(url)
        let response: OutlookMessageBody = try await performRequest(request)

        let body = response.body?.content ?? ""
        cacheBody(messageId, body: body)
        return body
    }

    func fetchAttachments(_ messageId: String) async throws -> [EmailAttachment] {
        if let cached = getCachedAttachments(messageId) {
            return cached
        }

        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let select = "id,name,contentType,size,isInline"
        let url = URL(string: "\(baseURL)/messages/\(messageId)/attachments?$select=\(select)")!
        let request = try await authorizedRequest(url)
        let response: OutlookAttachmentListResponse = try await performRequest(request)

        let attachments = (response.value ?? [])
            .filter { !($0.isInline ?? false) && $0.name != nil }
            .map { EmailAttachment(
                id: $0.id,
                messageId: messageId,
                filename: $0.name!,
                mimeType: $0.contentType ?? "application/octet-stream",
                size: $0.size ?? 0
            ) }

        cacheAttachments(messageId, attachments: attachments)
        return attachments
    }

    func downloadAttachmentData(_ attachment: EmailAttachment) async throws -> Data {
        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/messages/\(attachment.messageId)/attachments/\(attachment.id)?$select=contentBytes")!
        let request = try await authorizedRequest(url)
        let response: OutlookAttachment = try await performRequest(request)

        guard let base64 = response.contentBytes,
              let data = Data(base64Encoded: base64) else {
            throw OutlookError.apiError("Failed to decode attachment data")
        }
        return data
    }

    func prefetchBodies(for messageIds: [String]) {
        let count = min(messageIds.count, 5)
        Task.detached { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                for messageId in messageIds.prefix(5) {
                    group.addTask {
                        _ = try? await self?.fetchEmailBody(messageId)
                    }
                }
            }
            print("[Outlook Prefetch] Completed prefetch for \(count) emails")
        }
    }
}
