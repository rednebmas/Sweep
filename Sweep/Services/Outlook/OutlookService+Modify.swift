//
//  OutlookService+Modify.swift
//  Sweep

import Foundation

extension OutlookService {

    func archiveMessages(_ messageIds: [String]) async throws {
        for messageId in messageIds {
            try await moveMessage(messageId, to: "archive")
        }
    }

    func markAsRead(_ messageIds: [String]) async throws {
        for messageId in messageIds {
            try await updateMessage(messageId, isRead: true)
        }
    }

    func archiveAndMarkRead(_ messageIds: [String]) async throws {
        for messageId in messageIds {
            try await updateMessage(messageId, isRead: true)
            try await moveMessage(messageId, to: "archive")
        }
    }

    func markReadOnly(_ messageIds: [String]) async throws {
        try await markAsRead(messageIds)
    }

    func markAsSpam(_ messageId: String) async throws {
        try await moveMessage(messageId, to: "junkemail")
    }

    func blockSender(_ email: String) async throws {
        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/mailFolders/junkemail/messageRules")!
        var request = try await authorizedRequest(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let ruleBody: [String: Any] = [
            "displayName": "Block \(email)",
            "sequence": 1,
            "isEnabled": true,
            "conditions": [
                "senderContains": [email]
            ],
            "actions": [
                "delete": true
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: ruleBody)
        try await performVoidRequest(request)
    }

    func restoreMessages(_ messageIds: [String], wasArchived: Bool) async throws {
        for messageId in messageIds {
            try await updateMessage(messageId, isRead: false)
            if wasArchived {
                try await moveMessage(messageId, to: "inbox")
            }
        }
    }

    private func updateMessage(_ messageId: String, isRead: Bool) async throws {
        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/messages/\(messageId)")!
        var request = try await authorizedRequest(url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OutlookModifyRequest(isRead: isRead)
        request.httpBody = try JSONEncoder().encode(body)

        try await performVoidRequest(request)
    }

    private func moveMessage(_ messageId: String, to folder: String) async throws {
        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/messages/\(messageId)/move")!
        var request = try await authorizedRequest(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OutlookMoveRequest(destinationId: folder)
        request.httpBody = try JSONEncoder().encode(body)

        try await performVoidRequest(request)
    }
}
