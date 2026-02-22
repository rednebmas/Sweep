//
//  IMAPError.swift
//  Sweep

import Foundation

enum IMAPError: Error, LocalizedError {
    case notConnected
    case invalidCredentials
    case connectionFailed(String)
    case folderNotFound(String)
    case fetchFailed(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to IMAP server"
        case .invalidCredentials: return "Invalid email or password"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .folderNotFound(let name): return "Folder not found: \(name)"
        case .fetchFailed(let msg): return "Fetch failed: \(msg)"
        case .operationFailed(let msg): return "Operation failed: \(msg)"
        }
    }
}
