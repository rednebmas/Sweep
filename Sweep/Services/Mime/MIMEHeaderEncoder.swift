//
//  MIMEHeaderEncoder.swift
//  Sweep
//

import Foundation

enum MIMEHeaderEncoder {
    static func encode(_ value: String) -> String {
        guard !isASCII(value) else { return value }
        let base64 = Data(value.utf8).base64EncodedString()
        return "=?UTF-8?B?\(base64)?="
    }

    static func encodeAddress(_ participant: EmailParticipant) -> String {
        let name = participant.name
        guard !name.isEmpty, name != participant.email else { return participant.email }
        guard isASCII(name) else { return "\(encode(name)) <\(participant.email)>" }
        return participant.rfc5322
    }

    static func encodeAddressList(_ participants: [EmailParticipant]) -> String {
        participants.map(encodeAddress).joined(separator: ", ")
    }

    private static func isASCII(_ value: String) -> Bool {
        value.allSatisfy { $0.isASCII }
    }
}
