//
//  SubjectFormatter.swift
//  Sweep
//

import Foundation

enum SubjectFormatter {
    static func stripWrappingQuotes(_ subject: String) -> String {
        var cleaned = subject
        while cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 2 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    static func reply(_ subject: String) -> String {
        let cleaned = stripWrappingQuotes(subject)
        if cleaned.lowercased().hasPrefix("re:") { return cleaned }
        return "Re: \(cleaned)"
    }
}
