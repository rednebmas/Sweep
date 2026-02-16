//
//  GmailService+Fetch.swift
//  Sweep
//

import Foundation

extension GmailService {

    // MARK: - Fetch Threads

    func fetchThreads(since date: Date) async throws -> [EmailThread] {
        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }

        let timestamp = Int(date.timeIntervalSince1970)
        let query = "after:\(timestamp) in:inbox is:unread"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let url = URL(string: "\(baseURL)/threads?q=\(encodedQuery)&maxResults=100")!
        let request = try await authorizedRequest(url)
        let response: ThreadListResponse = try await performRequest(request)

        guard let threadRefs = response.threads else {
            return []
        }

        return try await withThrowingTaskGroup(of: EmailThread?.self) { group in
            for threadRef in threadRefs {
                group.addTask {
                    try await self.fetchThreadDetail(threadRef.id)
                }
            }

            var threads: [EmailThread] = []
            for try await thread in group {
                if let thread = thread {
                    threads.append(thread)
                }
            }

            return threads.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private static let threadDetailFields = [
        "id,snippet,messages(id,snippet,payload(headers,mimeType,filename,",
        "body(attachmentId,size),parts(mimeType,filename,body(attachmentId,size),",
        "headers,parts(mimeType,filename,body(attachmentId,size),headers,",
        "parts(mimeType,filename,body(attachmentId,size),headers)))))"
    ].joined()

    func fetchThreadDetail(_ threadId: String) async throws -> EmailThread? {
        let fields = Self.threadDetailFields.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? Self.threadDetailFields
        let url = URL(string: "\(baseURL)/threads/\(threadId)?format=full&fields=\(fields)")!
        let request = try await authorizedRequest(url)
        let response: ThreadFullResponse = try await performRequest(request)

        guard let firstMessage = response.messages?.first else {
            return nil
        }

        return parseThread(response, firstMessage: firstMessage)
    }

    private func parseThread(_ response: ThreadFullResponse, firstMessage: MessageFullResponse) -> EmailThread {
        let headers = firstMessage.payload?.headers ?? []

        let fromHeader = headers.first { $0.name.lowercased() == "from" }?.value ?? "Unknown"
        let subject = headers.first { $0.name.lowercased() == "subject" }?.value ?? "(No Subject)"
        let dateHeader = headers.first { $0.name.lowercased() == "date" }?.value
        let unsubscribeHeader = headers.first { $0.name.lowercased() == "list-unsubscribe" }?.value

        let (fromName, fromEmail) = parseFromHeader(fromHeader)
        let timestamp = parseDateHeader(dateHeader)
        let unsubscribeURL = parseUnsubscribeHeader(unsubscribeHeader)
        let snippet = decodeHTMLEntities(firstMessage.snippet ?? response.snippet ?? "")

        return EmailThread(
            id: response.id,
            accountId: accountId,
            providerType: .gmail,
            subject: subject,
            snippet: snippet,
            from: fromName,
            fromEmail: fromEmail,
            timestamp: timestamp,
            hasAttachments: detectAttachments(in: response),
            messageCount: response.messages?.count ?? 1,
            unsubscribeURL: unsubscribeURL,
            isKept: KeptThreadsStore.shared.isKept(response.id, accountId: accountId)
        )
    }

    private func detectAttachments(in response: ThreadFullResponse) -> Bool {
        response.messages?.contains { hasFileAttachments($0.payload) } ?? false
    }

    private func hasFileAttachments(_ payload: PayloadFullResponse?) -> Bool {
        guard let payload = payload else { return false }

        if let filename = payload.filename, !filename.isEmpty,
           payload.body?.attachmentId != nil,
           !isInlineImage(payload) {
            return true
        }

        return payload.parts?.contains { hasFileAttachments($0) } ?? false
    }

    private func parseUnsubscribeHeader(_ header: String?) -> URL? {
        guard let header = header else { return nil }

        let pattern = "<(https?://[^>]+)>"
        if let match = header.range(of: pattern, options: .regularExpression) {
            let urlString = String(header[match])
                .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            return URL(string: urlString)
        }
        return nil
    }

    func parseFromHeader(_ from: String) -> (name: String, email: String) {
        if let match = from.range(of: "<.*>", options: .regularExpression) {
            let email = String(from[match]).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            let name = String(from[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
            return (name.isEmpty ? email : name, email)
        }
        return (from, from)
    }

    func parseDateHeader(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss z"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return Date()
    }

    func fetchThreadDetails(_ threadId: String) async throws -> EmailThread {
        guard let thread = try await fetchThreadDetail(threadId) else {
            throw GmailError.invalidResponse
        }
        return thread
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
            ("&#x27;", "'"), ("&nbsp;", " ")
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}
