//
//  ArchiveSession.swift
//  Sweep
//

import Foundation

struct SweepSession: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let compositeIds: [String]
    let count: Int
    let wasArchived: Bool

    init(threads: [EmailThread], wasArchived: Bool = true) {
        self.id = UUID()
        self.timestamp = Date()
        self.compositeIds = threads.map(\.compositeId)
        self.count = threads.count
        self.wasArchived = wasArchived
    }

    func threadsByAccount() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for compositeId in compositeIds {
            let parts = compositeId.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let accountId = String(parts[0])
            let threadId = String(parts[1])
            result[accountId, default: []].append(threadId)
        }
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, wasArchived
        case compositeIds = "archivedThreadIds"
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
