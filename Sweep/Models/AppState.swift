//
//  AppState.swift
//  Sweep
//

import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var lastOpenedTimestamp: Date? {
        didSet {
            if let timestamp = lastOpenedTimestamp {
                UserDefaults.standard.set(timestamp, forKey: "lastOpenedTimestamp")
            }
        }
    }

    @Published var sweepSessions: [SweepSession] = [] {
        didSet {
            saveSweepSessions()
        }
    }

    @Published var isFirstLaunch: Bool

    @Published var snippetLines: Int {
        didSet {
            UserDefaults.standard.set(snippetLines, forKey: "snippetLines")
        }
    }

    @Published var archiveOnBackground: Bool {
        didSet {
            UserDefaults.standard.set(archiveOnBackground, forKey: "archiveOnBackground")
        }
    }

    @Published var manualSweep: Bool {
        didSet {
            UserDefaults.standard.set(manualSweep, forKey: "manualSweep")
        }
    }

    private init() {
        let savedTimestamp = UserDefaults.standard.object(forKey: "lastOpenedTimestamp") as? Date
        self.lastOpenedTimestamp = savedTimestamp
        self.isFirstLaunch = savedTimestamp == nil
        self.sweepSessions = Self.loadSweepSessions()
        self.snippetLines = UserDefaults.standard.object(forKey: "snippetLines") as? Int ?? 3
        self.archiveOnBackground = UserDefaults.standard.bool(forKey: "archiveOnBackground")
        self.manualSweep = UserDefaults.standard.object(forKey: "manualSweep") as? Bool ?? true
    }

    func updateEmailFetchTimestamp(newestEmailDate: Date) {
        lastOpenedTimestamp = newestEmailDate
        isFirstLaunch = false
    }

    func getEmailFetchDate() -> Date {
        if isFirstLaunch {
            // First launch: show emails from last 24 hours
            return Date().addingTimeInterval(-24 * 60 * 60)
        } else {
            // Subsequent opens: use last opened timestamp
            return lastOpenedTimestamp ?? Date().addingTimeInterval(-24 * 60 * 60)
        }
    }

    func addSweepSession(_ session: SweepSession) {
        sweepSessions.insert(session, at: 0)
        // Keep only last 10 sessions
        if sweepSessions.count > 10 {
            sweepSessions = Array(sweepSessions.prefix(10))
        }
    }

    private func saveSweepSessions() {
        if let data = try? JSONEncoder().encode(sweepSessions) {
            UserDefaults.standard.set(data, forKey: "archiveSessions")
        }
    }

    private static func loadSweepSessions() -> [SweepSession] {
        guard let data = UserDefaults.standard.data(forKey: "archiveSessions"),
              let sessions = try? JSONDecoder().decode([SweepSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func updateSession(_ session: SweepSession) {
        guard let index = sweepSessions.firstIndex(where: { $0.id == session.id }) else { return }
        sweepSessions[index] = session
    }

    func clearSweepSession(_ session: SweepSession) {
        sweepSessions.removeAll { $0.id == session.id }
    }
}
