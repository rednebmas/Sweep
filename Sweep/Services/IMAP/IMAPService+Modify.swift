//
//  IMAPService+Modify.swift
//  Sweep

import Foundation
import SwiftMail

extension IMAPService {
    func archiveMessages(_ uids: [String]) async throws {
        try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            try await server.move(messages: self.uidSet(from: uids), to: self.folderPaths.archive)
        }
    }

    func markAsRead(_ uids: [String]) async throws {
        try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            try await server.store(flags: [.seen], on: self.uidSet(from: uids), operation: .add)
        }
    }

    func archiveAndMarkRead(_ uids: [String]) async throws {
        try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            let set = self.uidSet(from: uids)
            try await server.store(flags: [.seen], on: set, operation: .add)
            try await server.move(messages: set, to: self.folderPaths.archive)
        }
    }

    func markReadOnly(_ uids: [String]) async throws {
        try await markAsRead(uids)
    }

    func markAsSpam(_ uid: String) async throws {
        try await withConnection { server in
            _ = try await server.selectMailbox(self.folderPaths.inbox)
            try await server.move(messages: self.uidSet(from: [uid]), to: self.folderPaths.junk)
        }
    }

    func restoreMessages(_ uids: [String], wasArchived: Bool) async throws {
        let sourceFolder = wasArchived ? folderPaths.archive : folderPaths.junk
        try await withConnection { server in
            _ = try await server.selectMailbox(sourceFolder)
            let set = self.uidSet(from: uids)
            try await server.store(flags: [.seen], on: set, operation: .remove)
            try await server.move(messages: set, to: self.folderPaths.inbox)
        }
    }

    private func uidSet(from strings: [String]) -> UIDSet {
        var set = UIDSet()
        for s in strings {
            if let raw = UInt32(s) {
                set.insert(UID(raw))
            }
        }
        return set
    }
}
