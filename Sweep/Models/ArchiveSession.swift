//
//  ArchiveSession.swift
//  Sweep
//

import Foundation

struct SweepSession: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let threadIds: [String]
    let count: Int
    let wasArchived: Bool

    init(threadIds: [String], wasArchived: Bool = true) {
        self.id = UUID()
        self.timestamp = Date()
        self.threadIds = threadIds
        self.count = threadIds.count
        self.wasArchived = wasArchived
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, wasArchived
        case threadIds = "archivedThreadIds"
        case count = "archivedCount"
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

typealias ArchiveSession = SweepSession
