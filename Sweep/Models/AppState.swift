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

    @Published var archiveSessions: [ArchiveSession] = [] {
        didSet {
            saveArchiveSessions()
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

    private init() {
        let savedTimestamp = UserDefaults.standard.object(forKey: "lastOpenedTimestamp") as? Date
        self.lastOpenedTimestamp = savedTimestamp
        self.isFirstLaunch = savedTimestamp == nil
        self.archiveSessions = Self.loadArchiveSessions()
        self.snippetLines = UserDefaults.standard.object(forKey: "snippetLines") as? Int ?? 3
        self.archiveOnBackground = UserDefaults.standard.bool(forKey: "archiveOnBackground") // defaults to false
    }

    func recordAppOpen() {
        let now = Date()
        lastOpenedTimestamp = now
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

    func addArchiveSession(_ session: ArchiveSession) {
        archiveSessions.insert(session, at: 0)
        // Keep only last 10 sessions
        if archiveSessions.count > 10 {
            archiveSessions = Array(archiveSessions.prefix(10))
        }
    }

    private func saveArchiveSessions() {
        if let data = try? JSONEncoder().encode(archiveSessions) {
            UserDefaults.standard.set(data, forKey: "archiveSessions")
        }
    }

    private static func loadArchiveSessions() -> [ArchiveSession] {
        guard let data = UserDefaults.standard.data(forKey: "archiveSessions"),
              let sessions = try? JSONDecoder().decode([ArchiveSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func clearArchiveSession(_ session: ArchiveSession) {
        archiveSessions.removeAll { $0.id == session.id }
    }
}
