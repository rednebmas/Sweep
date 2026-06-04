//
//  ReplyContext.swift
//  Sweep
//

import Foundation

struct ReplyContext {
    let threadId: String
    let messageIdHeader: String?
    let references: String?
    let subject: String
    let from: EmailParticipant
    let to: [EmailParticipant]
    let cc: [EmailParticipant]
    let date: Date
    let selfEmail: String?
    let originalBodyText: String
}
