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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        archivedThreadIds = try container.decode([String].self, forKey: .archivedThreadIds)
        archivedCount = try container.decode(Int.self, forKey: .archivedCount)
        wasArchived = try container.decodeIfPresent(Bool.self, forKey: .wasArchived) ?? true
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
