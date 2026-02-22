//
//  IMAPServerDetector.swift
//  Sweep

import Foundation

struct IMAPServerConfig {
    let host: String
    let port: UInt32
    let useTLS: Bool
}

enum IMAPServerDetector {
    private static let knownServers: [String: IMAPServerConfig] = [
        "icloud.com": IMAPServerConfig(host: "imap.mail.me.com", port: 993, useTLS: true),
        "me.com": IMAPServerConfig(host: "imap.mail.me.com", port: 993, useTLS: true),
        "mac.com": IMAPServerConfig(host: "imap.mail.me.com", port: 993, useTLS: true),
        "yahoo.com": IMAPServerConfig(host: "imap.mail.yahoo.com", port: 993, useTLS: true),
        "yahoo.co.uk": IMAPServerConfig(host: "imap.mail.yahoo.com", port: 993, useTLS: true),
        "aol.com": IMAPServerConfig(host: "imap.aol.com", port: 993, useTLS: true),
        "fastmail.com": IMAPServerConfig(host: "imap.fastmail.com", port: 993, useTLS: true),
        "fastmail.fm": IMAPServerConfig(host: "imap.fastmail.com", port: 993, useTLS: true),
        "zoho.com": IMAPServerConfig(host: "imap.zoho.com", port: 993, useTLS: true),
        "protonmail.com": IMAPServerConfig(host: "127.0.0.1", port: 1143, useTLS: false),
        "proton.me": IMAPServerConfig(host: "127.0.0.1", port: 1143, useTLS: false),
        "gmx.com": IMAPServerConfig(host: "imap.gmx.com", port: 993, useTLS: true),
        "gmx.net": IMAPServerConfig(host: "imap.gmx.net", port: 993, useTLS: true),
        "mail.com": IMAPServerConfig(host: "imap.mail.com", port: 993, useTLS: true),
        "yandex.com": IMAPServerConfig(host: "imap.yandex.com", port: 993, useTLS: true),
        "outlook.com": IMAPServerConfig(host: "outlook.office365.com", port: 993, useTLS: true),
        "hotmail.com": IMAPServerConfig(host: "outlook.office365.com", port: 993, useTLS: true),
        "live.com": IMAPServerConfig(host: "outlook.office365.com", port: 993, useTLS: true),
    ]

    static func detect(email: String) -> IMAPServerConfig? {
        guard let domain = email.split(separator: "@").last?.lowercased() else { return nil }
        return knownServers[domain]
    }
}
