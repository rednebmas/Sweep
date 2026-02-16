//
//  KeptThread.swift
//  Sweep

import Foundation
import SwiftData

@Model
final class KeptThread {
    @Attribute(.unique) var compositeId: String
    var threadId: String
    var accountId: String
    var keptAt: Date

    // Cached thread data (defaults allow lightweight migration)
    var subject: String = ""
    var snippet: String = ""
    var from: String = ""
    var fromEmail: String = ""
    var cachedTimestamp: Date = Date.distantPast
    var hasAttachments: Bool = false
    var messageCount: Int = 0
    var providerTypeRaw: String = ""

    var hasCachedData: Bool { !subject.isEmpty }

    init(threadId: String, accountId: String) {
        self.compositeId = "\(accountId):\(threadId)"
        self.threadId = threadId
        self.accountId = accountId
        self.keptAt = Date()
    }

    init(thread: EmailThread) {
        self.compositeId = thread.compositeId
        self.threadId = thread.id
        self.accountId = thread.accountId
        self.keptAt = Date()
        updateCachedData(from: thread)
    }

    func updateCachedData(from thread: EmailThread) {
        subject = thread.subject
        snippet = thread.snippet
        from = thread.from
        fromEmail = thread.fromEmail
        cachedTimestamp = thread.timestamp
        hasAttachments = thread.hasAttachments
        messageCount = thread.messageCount
        providerTypeRaw = thread.providerType.rawValue
    }

    func toEmailThread() -> EmailThread {
        EmailThread(
            id: threadId,
            accountId: accountId,
            providerType: EmailProviderType(rawValue: providerTypeRaw) ?? .gmail,
            subject: subject,
            snippet: snippet,
            from: from,
            fromEmail: fromEmail,
            timestamp: cachedTimestamp,
            hasAttachments: hasAttachments,
            messageCount: messageCount,
            unsubscribeURL: nil,
            isKept: true
        )
    }
}
