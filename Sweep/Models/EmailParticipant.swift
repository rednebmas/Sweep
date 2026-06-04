//
//  EmailParticipant.swift
//  Sweep
//

import Foundation

struct EmailParticipant: Hashable, Codable {
    let name: String
    let email: String

    var displayName: String {
        name.isEmpty ? email : name
    }

    var rfc5322: String {
        guard !name.isEmpty, name != email else { return email }
        return "\(quotedName) <\(email)>"
    }

    private var quotedName: String {
        let specials = CharacterSet(charactersIn: "()<>[]:;@\\,.\"")
        guard name.rangeOfCharacter(from: specials) != nil else { return name }
        let escaped = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func parse(_ token: String) -> EmailParticipant? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let match = trimmed.range(of: "<[^>]*>", options: .regularExpression) else {
            return EmailParticipant(name: "", email: trimmed)
        }

        let email = String(trimmed[match]).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let rawName = String(trimmed[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
        return EmailParticipant(name: unquote(rawName), email: email)
    }

    static func parseList(_ headerValue: String) -> [EmailParticipant] {
        splitTopLevel(headerValue).compactMap(parse).filter { !$0.email.isEmpty }
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
        return String(value.dropFirst().dropLast())
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func splitTopLevel(_ value: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        var escaped = false

        for character in value {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                current.append(character)
                escaped = true
            } else if character == "\"" {
                inQuotes.toggle()
                current.append(character)
            } else if character == "," && !inQuotes {
                tokens.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        tokens.append(current)
        return tokens
    }
}
