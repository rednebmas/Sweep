//
//  SettingsView.swift
//  Sweep
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var gmailService = GmailService.shared
    @State private var showingRestoreAlert = false
    @State private var sessionToRestore: ArchiveSession?

    var body: some View {
        List {
            accountSection
            displaySection
            behaviorSection
            undoSection
            aboutSection
        }
        .navigationTitle("Settings")
        .alert("Restore Emails", isPresented: $showingRestoreAlert, presenting: sessionToRestore) { session in
            Button("Restore") {
                Task { await restoreSession(session) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { session in
            Text("Restore \(session.archivedCount) emails to your inbox?")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if gmailService.isAuthenticated {
                HStack {
                    Text("Signed in as")
                    Spacer()
                    Text(gmailService.userEmail ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                Button("Sign Out", role: .destructive) {
                    gmailService.signOut()
                }
            } else {
                Button("Sign in with Google") {
                    Task {
                        try? await gmailService.signIn()
                    }
                }
            }
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Picker("Preview Lines", selection: $appState.snippetLines) {
                ForEach(1...5, id: \.self) { lines in
                    Text("\(lines)").tag(lines)
                }
            }
        }
    }

    private var behaviorSection: some View {
        Section("Behavior") {
            Toggle("Archive emails", isOn: $appState.archiveOnBackground)
            Text("When disabled, emails are only marked as read. When enabled, non-kept emails are also archived.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var undoSection: some View {
        Section("Undo Archive") {
            if appState.archiveSessions.isEmpty {
                Text("No recent archive sessions")
                    .foregroundColor(.secondary)
            } else {
                ForEach(appState.archiveSessions) { session in
                    Button {
                        sessionToRestore = session
                        showingRestoreAlert = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(session.archivedCount) emails archived")
                                Text(session.displayDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func restoreSession(_ session: ArchiveSession) async {
        do {
            try await GmailService.shared.restoreThreads(session.archivedThreadIds)
            appState.clearArchiveSession(session)
        } catch {
            // TODO: Show error
        }
    }
}
