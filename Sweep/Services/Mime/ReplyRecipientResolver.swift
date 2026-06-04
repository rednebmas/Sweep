//
//  ReplyRecipientResolver.swift
//  Sweep
//

import Foundation

enum ReplyRecipientResolver {
    typealias Recipients = (to: [EmailParticipant], cc: [EmailParticipant])

    static func resolve(_ mode: ReplyMode, context: ReplyContext) -> Recipients {
        switch mode {
        case .reply: return reply(context)
        case .replyAll: return replyAll(context)
        }
    }

    static func reply(_ context: ReplyContext) -> Recipients {
        (to: [context.from], cc: [])
    }

    static func replyAll(_ context: ReplyContext) -> Recipients {
        var seen = Set<String>()
        if let selfEmail = context.selfEmail?.lowercased(), !selfEmail.isEmpty {
            seen.insert(selfEmail)
        }

        let to = dedup([context.from] + context.to, seen: &seen)
        let cc = dedup(context.cc, seen: &seen)

        guard to.isEmpty else { return (to: to, cc: cc) }
        return (to: [context.from], cc: cc)
    }

    private static func dedup(_ participants: [EmailParticipant], seen: inout Set<String>) -> [EmailParticipant] {
        var result: [EmailParticipant] = []
        for participant in participants {
            let key = participant.email.lowercased()
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(participant)
        }
        return result
    }
}
