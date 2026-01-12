//
//  KeptThread.swift
//  Sweep

import Foundation
import SwiftData

@Model
final class KeptThread {
    @Attribute(.unique) var threadId: String
    var keptAt: Date

    init(threadId: String) {
        self.threadId = threadId
        self.keptAt = Date()
    }
}
