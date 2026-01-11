//
//  ArchiveSession.swift
//  Sweep
//

import Foundation

struct ArchiveSession: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let archivedThreadIds: [String]
    let archivedCount: Int
    let wasArchived: Bool

    init(archivedThreadIds: [String], wasArchived: Bool = true) {
        self.id = UUID()
        self.timestamp = Date()
        self.archivedThreadIds = archivedThreadIds
        self.archivedCount = archivedThreadIds.count
        self.wasArchived = wasArchived
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
