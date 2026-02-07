//
//  GmailService+Modify.swift
//  Sweep
//

import Foundation

extension GmailService {

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

    func markReadOnly(_ threadIds: [String]) async throws {
        try await batchModifyThreads(threadIds, addLabels: [], removeLabels: ["UNREAD"])
    }

    func batchModifyThreads(_ threadIds: [String], addLabels: [String], removeLabels: [String]) async throws {
        guard isAuthenticated else {
            throw GmailError.notAuthenticated
        }
        guard !threadIds.isEmpty else { return }

        let batchURL = URL(string: "https://www.googleapis.com/batch/gmail/v1")!
        var request = try await authorizedRequest(batchURL)
        request.httpMethod = "POST"

        let boundary = "batch_\(UUID().uuidString)"
        request.setValue("multipart/mixed; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

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

    func modifyThread(_ threadId: String, addLabels: [String], removeLabels: [String]) async throws {
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


    // MARK: - Restore (Undo)

    func restoreThreads(_ threadIds: [String], wasArchived: Bool) async throws {
        if wasArchived {
            try await batchModifyThreads(threadIds, addLabels: ["INBOX", "UNREAD"], removeLabels: [])
        } else {
            try await batchModifyThreads(threadIds, addLabels: ["UNREAD"], removeLabels: [])
        }
    }

    // MARK: - Kept Label

    func getOrCreateKeptLabelId() async throws -> String {
        if let cached = keptLabelId { return cached }

        let url = URL(string: "\(baseURL)/labels")!
        let request = try await authorizedRequest(url)
        let response: LabelListResponse = try await performRequest(request)

        if let existing = response.labels?.first(where: { $0.name == "kept" }) {
            keptLabelId = existing.id
            return existing.id
        }

        let createURL = URL(string: "\(baseURL)/labels")!
        var createRequest = try await authorizedRequest(createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateLabelRequest(
            name: "kept",
            labelListVisibility: "labelHide",
            messageListVisibility: "hide"
        )
        createRequest.httpBody = try JSONEncoder().encode(body)

        let label: GmailLabel = try await performRequest(createRequest)
        keptLabelId = label.id
        return label.id
    }

    func applyKeptLabel(_ threadIds: [String]) async throws {
        let labelId = try await getOrCreateKeptLabelId()
        try await batchModifyThreads(threadIds, addLabels: [labelId], removeLabels: [])
    }

    func removeKeptLabel(_ threadIds: [String]) async throws {
        let labelId = try await getOrCreateKeptLabelId()
        try await batchModifyThreads(threadIds, addLabels: [], removeLabels: [labelId])
    }

}
