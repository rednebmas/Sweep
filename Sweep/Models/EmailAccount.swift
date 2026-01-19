//
//  EmailAccount.swift
//  Sweep

import Foundation

struct EmailAccount: Identifiable, Codable, Hashable {
    let id: String
    let providerType: EmailProviderType
    let email: String
    let addedAt: Date
    var isEnabled: Bool

    var displayName: String {
        email.components(separatedBy: "@").first ?? email
    }
}
