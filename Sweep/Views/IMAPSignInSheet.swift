//
//  IMAPSignInSheet.swift
//  Sweep

import SwiftUI

struct IMAPSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountManager = AccountManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var host = ""
    @State private var port = ""
    @State private var useTLS = true
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var serverDetected = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onChange(of: email) { detectServer() }

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section("Server") {
                    TextField("IMAP Host", text: $host)
                        .autocapitalization(.none)
                        .keyboardType(.URL)

                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)

                    Toggle("Use TLS", isOn: $useTLS)
                }

                if serverDetected {
                    Section {
                        Label("Server auto-detected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        connect()
                    } label: {
                        HStack {
                            Spacer()
                            if isConnecting {
                                ProgressView()
                            } else {
                                Text("Connect")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isConnecting || email.isEmpty || password.isEmpty || host.isEmpty)
                }

                Section {
                    Text("For iCloud, Yahoo, and other providers with two-factor authentication, you may need to use an app-specific password.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("IMAP Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func detectServer() {
        guard let config = IMAPServerDetector.detect(email: email) else {
            serverDetected = false
            return
        }
        host = config.host
        port = String(config.port)
        useTLS = config.useTLS
        serverDetected = true
    }

    private func connect() {
        isConnecting = true
        errorMessage = nil

        let portValue = UInt32(port) ?? 993
        let credentials = IMAPCredentials(
            email: email,
            password: password,
            host: host,
            port: portValue,
            useTLS: useTLS
        )

        Task {
            do {
                try await accountManager.addIMAPAccount(credentials: credentials)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }
}
