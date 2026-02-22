//
//  IMAPFolderResolver.swift
//  Sweep

import Foundation
import SwiftMail

struct IMAPFolderPaths {
    let inbox: String
    let archive: String
    let junk: String
    let trash: String

    static let defaults = IMAPFolderPaths(
        inbox: "INBOX",
        archive: "Archive",
        junk: "Junk",
        trash: "Trash"
    )
}

enum IMAPFolderResolver {
    static func resolve(server: IMAPServer) async throws -> IMAPFolderPaths {
        let mailboxes = try await server.listMailboxes()

        let archive = mailboxes.first { $0.attributes.contains(.archive) }?.name
            ?? mailboxes.first { ["archive", "[gmail]/all mail"].contains($0.name.lowercased()) }?.name
            ?? "Archive"

        let junk = mailboxes.first { $0.attributes.contains(.junk) }?.name
            ?? mailboxes.first { ["junk", "spam", "bulk mail"].contains($0.name.lowercased()) }?.name
            ?? "Junk"

        let trash = mailboxes.first { $0.attributes.contains(.trash) }?.name
            ?? mailboxes.first { ["trash", "deleted items", "deleted messages"].contains($0.name.lowercased()) }?.name
            ?? "Trash"

        return IMAPFolderPaths(inbox: "INBOX", archive: archive, junk: junk, trash: trash)
    }
}
