//
//  IMAPCredentials.swift
//  Sweep

import Foundation

struct IMAPCredentials: Codable {
    let email: String
    let password: String
    let host: String
    let port: UInt32
    let useTLS: Bool

    var accountId: String {
        Data(email.utf8).base64EncodedString()
    }
}
