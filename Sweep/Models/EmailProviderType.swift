//
//  EmailProviderType.swift
//  Sweep

import SwiftUI

enum EmailProviderType: String, Codable, CaseIterable {
    case gmail
    case outlook

    var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .outlook: return "Outlook"
        }
    }

    var brandColor: Color {
        switch self {
        case .gmail: return Color(red: 0.92, green: 0.26, blue: 0.21)
        case .outlook: return Color(red: 0, green: 0.47, blue: 0.83)
        }
    }
}
