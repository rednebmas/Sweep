//
//  TrialService.swift
//  Sweep

import Foundation
import Combine

@MainActor
class TrialService: ObservableObject {
    static let shared = TrialService()

    private let trialStartKey = "trialStartDate"
    private let trialDuration: TimeInterval = 30 * 24 * 60 * 60

    private init() {
        initializeTrialIfNeeded()
    }

    var trialStartDate: Date? {
        UserDefaults.standard.object(forKey: trialStartKey) as? Date
    }

    var isTrialActive: Bool {
        guard let start = trialStartDate else { return true }
        return Date().timeIntervalSince(start) < trialDuration
    }

    var trialExpired: Bool { !isTrialActive }

    var daysRemaining: Int {
        guard let start = trialStartDate else { return 30 }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = trialDuration - elapsed
        return max(0, Int(ceil(remaining / (24 * 60 * 60))))
    }

    private func initializeTrialIfNeeded() {
        if UserDefaults.standard.object(forKey: trialStartKey) == nil {
            UserDefaults.standard.set(Date(), forKey: trialStartKey)
        }
    }
}
