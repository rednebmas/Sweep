//
//  EmailProviderType.swift
//  Sweep

import SwiftUI

enum EmailProviderType: String, Codable, CaseIterable {
    case gmail
    case outlook
    case imap

    var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .outlook: return "Outlook"
        case .imap: return "IMAP"
        }
    }

    var brandColor: Color {
        switch self {
        case .gmail: return Color(red: 0.92, green: 0.26, blue: 0.21)
        case .outlook: return Color(red: 0, green: 0.47, blue: 0.83)
        case .imap: return Color(red: 0.4, green: 0.4, blue: 0.45)
        }
    }
}
