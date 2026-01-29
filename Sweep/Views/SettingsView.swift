//
//  SettingsView.swift
//  Sweep
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var selectedSession: ArchiveSession?
    @State private var showAllSweeps = false
    @State private var showAddAccount = false

    var body: some View {
        List {
            SubscriptionSectionView()
            accountSection
            displaySection
            behaviorSection
            undoSection
            aboutSection
        }
        .navigationTitle("Settings")
        .sheet(item: $selectedSession) { session in
            SweepSessionDetailView(session: session) {
                selectedSession = nil
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
        }
    }

    private var accountSection: some View {
        Section("Accounts") {
            ForEach(accountManager.accounts) { account in
                AccountRowView(account: account) {
                    accountManager.removeAccount(account)
                }
            }
            Button {
                showAddAccount = true
            } label: {
                Label("Add Account", systemImage: "plus.circle")
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

    private var visibleSessions: [ArchiveSession] {
        if showAllSweeps {
            return appState.archiveSessions
        }
        return Array(appState.archiveSessions.prefix(3))
    }

    private var undoSection: some View {
        Section("Undo Sweeps") {
            if appState.archiveSessions.isEmpty {
                Text("No recent sweeps")
                    .foregroundColor(.secondary)
            } else {
                ForEach(visibleSessions) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        sweepRowLabel(for: session)
                    }
                    .foregroundColor(.primary)
                }
                if appState.archiveSessions.count > 3 && !showAllSweeps {
                    Button {
                        showAllSweeps = true
                    } label: {
                        Text("Show More (\(appState.archiveSessions.count - 3) more)")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    private func sweepRowLabel(for session: ArchiveSession) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(session.count) emails")
                HStack(spacing: 4) {
                    Text(session.displayDate)
                    Text("•")
                    Text(session.wasArchived ? "Archived" : "Read")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            Text("The fastest way to read your email")
                .font(.subheadline)
                .italic()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
    }
}
