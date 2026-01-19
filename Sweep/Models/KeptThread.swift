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

    init(threadId: String, accountId: String) {
        self.compositeId = "\(accountId):\(threadId)"
        self.threadId = threadId
        self.accountId = accountId
        self.keptAt = Date()
    }
}
