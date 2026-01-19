//
//  AddAccountSheet.swift
//  Sweep

import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var isAddingAccount = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        addGmailAccount()
                    } label: {
                        HStack {
                            Circle()
                                .fill(EmailProviderType.gmail.brandColor)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 14))
                                }
                            Text("Gmail")
                                .foregroundColor(.primary)
                            Spacer()
                            if isAddingAccount {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isAddingAccount)

                    Button {
                        // Outlook - Phase 6
                    } label: {
                        HStack {
                            Circle()
                                .fill(EmailProviderType.outlook.brandColor)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 14))
                                }
                            Text("Outlook")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Coming Soon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(true)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addGmailAccount() {
        isAddingAccount = true
        errorMessage = nil

        Task {
            do {
                try await accountManager.addGmailAccount()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isAddingAccount = false
        }
    }
}
