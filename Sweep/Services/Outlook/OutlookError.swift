//
//  OutlookError.swift
//  Sweep

import Foundation

enum OutlookError: Error, LocalizedError {
    case notConfigured
    case notAuthenticated
    case noRootViewController
    case noResult
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Outlook is not configured"
        case .notAuthenticated: return "Not signed in to Outlook"
        case .noRootViewController: return "Could not find root view controller"
        case .noResult: return "Authentication did not return a result"
        case .apiError(let message): return "Outlook API error: \(message)"
        }
    }
}
