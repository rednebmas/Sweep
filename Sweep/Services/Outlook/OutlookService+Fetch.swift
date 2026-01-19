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
