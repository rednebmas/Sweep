//
//  OutgoingReply.swift
//  Sweep
//

import Foundation

struct OutgoingReply {
    let threadId: String
    let from: EmailParticipant
    let to: [EmailParticipant]
    let cc: [EmailParticipant]
    let subject: String
    let inReplyTo: String?
    let references: String?
    let bodyPlainText: String
    let quotedOriginal: ReplyContext
}
