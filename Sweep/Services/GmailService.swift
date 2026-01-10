//
//  GmailService.swift
//  Sweep
//

import Foundation
import Combine

enum GmailError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to Gmail"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "Gmail API error: \(message)"
        case .invalidResponse:
            return "Invalid response from Gmail"
        }
    }
}

@MainActor
class GmailService: ObservableObject {
    static let shared = GmailService()

    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let authService = AuthService.shared

    var isAuthenticated: Bool { authService.isAuthenticated && authService.accessToken != nil }
    var userEmail: String? { authService.userEmail }

    private init() {}

    // MARK: - Auth Passthrough

    func signIn() async throws {
        try await authService.signIn()
    }

    func signOut() {
        authService.signOut()
    }

    // MARK: - API Helpers

    private func authorizedRequest(_ url: URL) async throws -> URLRequest {
        try await authService.refreshTokenIfNeeded()

        guard let token = authService.accessToken else {
            throw GmailError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GmailError.notAuthenticated
        }

        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError(errorMessage)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Fetch Threads

    func fetchThreads(since date: Date) async throws -> [EmailThread] {
        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }

        let timestamp = Int(date.timeIntervalSince1970)
        let query = "after:\(timestamp) in:inbox"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let url = URL(string: "\(baseURL)/threads?q=\(encodedQuery)&maxResults=100")!
        let request = try await authorizedRequest(url)
        let response: ThreadListResponse = try await performRequest(request)

        guard let threadRefs = response.threads else {
            return []
        }

        // Fetch thread details in parallel
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

            // Sort oldest first
            return threads.sorted { $0.timestamp < $1.timestamp }
        }
    }

    private func fetchThreadDetail(_ threadId: String) async throws -> EmailThread? {
        let url = URL(string: "\(baseURL)/threads/\(threadId)?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date")!
        let request = try await authorizedRequest(url)

        let response: ThreadDetailResponse = try await performRequest(request)

        guard let firstMessage = response.messages?.first else {
            return nil
        }

        return parseThread(response, firstMessage: firstMessage)
    }

    private func parseThread(_ response: ThreadDetailResponse, firstMessage: MessageResponse) -> EmailThread {
        let headers = firstMessage.payload?.headers ?? []

        let fromHeader = headers.first { $0.name.lowercased() == "from" }?.value ?? "Unknown"
        let subject = headers.first { $0.name.lowercased() == "subject" }?.value ?? "(No Subject)"
        let dateHeader = headers.first { $0.name.lowercased() == "date" }?.value

        let (fromName, fromEmail) = parseFromHeader(fromHeader)
        let timestamp = parseDateHeader(dateHeader)

        return EmailThread(
            id: response.id,
            subject: subject,
            snippet: response.snippet ?? "",
            from: fromName,
            fromEmail: fromEmail,
            timestamp: timestamp,
            hasAttachments: false, // TODO: check payload parts
            messageCount: response.messages?.count ?? 1
        )
    }

    private func parseFromHeader(_ from: String) -> (name: String, email: String) {
        // Format: "Name <email@example.com>" or just "email@example.com"
        if let match = from.range(of: "<.*>", options: .regularExpression) {
            let email = String(from[match]).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            let name = String(from[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
            return (name.isEmpty ? email : name, email)
        }
        return (from, from)
    }

    private func parseDateHeader(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try common formats
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

    // MARK: - Archive Threads

    func archiveThreads(_ threadIds: [String]) async throws {
        try await batchModifyThreads(threadIds, addLabels: [], removeLabels: ["INBOX"])
    }

    // MARK: - Mark as Read

    func markAsRead(_ threadIds: [String]) async throws {
        try await batchModifyThreads(threadIds, addLabels: [], removeLabels: ["UNREAD"])
    }

    func archiveAndMarkRead(_ threadIds: [String]) async throws {
        try await batchModifyThreads(threadIds, addLabels: [], removeLabels: ["INBOX", "UNREAD"])
    }

    private func batchModifyThreads(_ threadIds: [String], addLabels: [String], removeLabels: [String]) async throws {
        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }
        guard !threadIds.isEmpty else { return }

        // Gmail batch API endpoint
        let batchURL = URL(string: "https://www.googleapis.com/batch/gmail/v1")!
        var request = try await authorizedRequest(batchURL)
        request.httpMethod = "POST"

        let boundary = "batch_\(UUID().uuidString)"
        request.setValue("multipart/mixed; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = ""
        for (index, threadId) in threadIds.enumerated() {
            let modifyBody = try JSONEncoder().encode(ModifyRequest(addLabelIds: addLabels, removeLabelIds: removeLabels))
            let modifyJSON = String(data: modifyBody, encoding: .utf8) ?? "{}"

            body += "--\(boundary)\r\n"
            body += "Content-Type: application/http\r\n"
            body += "Content-ID: <item\(index)>\r\n\r\n"
            body += "POST /gmail/v1/users/me/threads/\(threadId)/modify\r\n"
            body += "Content-Type: application/json\r\n\r\n"
            body += "\(modifyJSON)\r\n"
        }
        body += "--\(boundary)--"

        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            throw GmailError.apiError("Batch modify failed")
        }
    }

    private func modifyThread(_ threadId: String, addLabels: [String], removeLabels: [String]) async throws {
        let url = URL(string: "\(baseURL)/threads/\(threadId)/modify")!
        var request = try await authorizedRequest(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ModifyRequest(addLabelIds: addLabels, removeLabelIds: removeLabels)
        request.httpBody = try JSONEncoder().encode(body)

        let _: EmptyResponse = try await performRequest(request)
    }

    // MARK: - Spam / Block

    func markAsSpam(_ threadId: String) async throws {
        try await modifyThread(threadId, addLabels: ["SPAM"], removeLabels: ["INBOX"])
    }

    func blockSender(_ email: String) async throws {
        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/settings/filters")!
        var request = try await authorizedRequest(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let filter = CreateFilterRequest(
            criteria: FilterCriteria(from: email),
            action: FilterAction(removeLabelIds: ["INBOX"], addLabelIds: ["TRASH"])
        )
        request.httpBody = try JSONEncoder().encode(filter)

        let _: FilterResponse = try await performRequest(request)
    }

    func unsubscribe(_ threadId: String) async throws {
        // For now, just archive - proper unsubscribe requires parsing List-Unsubscribe header
        try await archiveThreads([threadId])
    }

    // MARK: - Restore (Undo)

    func restoreThreads(_ threadIds: [String]) async throws {
        try await batchModifyThreads(threadIds, addLabels: ["INBOX"], removeLabels: [])
    }

    // MARK: - Thread Details

    func fetchThreadDetails(_ threadId: String) async throws -> EmailThread {
        guard let thread = try await fetchThreadDetail(threadId) else {
            throw GmailError.invalidResponse
        }
        return thread
    }
}

// MARK: - API Response Types

private struct ThreadListResponse: Codable {
    let threads: [ThreadRef]?
    let nextPageToken: String?
}

private struct ThreadRef: Codable {
    let id: String
    let historyId: String?
}

private struct ThreadDetailResponse: Codable {
    let id: String
    let snippet: String?
    let messages: [MessageResponse]?
}

private struct MessageResponse: Codable {
    let id: String
    let payload: PayloadResponse?
}

private struct PayloadResponse: Codable {
    let headers: [HeaderResponse]?
}

private struct HeaderResponse: Codable {
    let name: String
    let value: String
}

private struct ModifyRequest: Codable {
    let addLabelIds: [String]
    let removeLabelIds: [String]
}

private struct EmptyResponse: Codable {}

private struct CreateFilterRequest: Codable {
    let criteria: FilterCriteria
    let action: FilterAction
}

private struct FilterCriteria: Codable {
    let from: String
}

private struct FilterAction: Codable {
    let removeLabelIds: [String]
    let addLabelIds: [String]
}

private struct FilterResponse: Codable {
    let id: String?
}
