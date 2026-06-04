//
//  ReplyMode.swift
//  Sweep
//

import Foundation

enum ReplyMode: String, Identifiable {
    case reply
    case replyAll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reply: return "Reply"
        case .replyAll: return "Reply All"
        }
    }
}
