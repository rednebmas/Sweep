//
//  AddAccountSheet.swift
//  Sweep

import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var isAddingGmail = false
    @State private var isAddingOutlook = false
    @State private var errorMessage: String?

    private var isAddingAccount: Bool { isAddingGmail || isAddingOutlook }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        addGmailAccount()
                    } label: {
                        providerRow(
                            type: .gmail,
                            isLoading: isAddingGmail
                        )
                    }
                    .disabled(isAddingAccount)

                    Button {
                        addOutlookAccount()
                    } label: {
                        providerRow(
                            type: .outlook,
                            isLoading: isAddingOutlook
                        )
                    }
                    .disabled(isAddingAccount)
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

    private func providerRow(type: EmailProviderType, isLoading: Bool) -> some View {
        HStack {
            Circle()
                .fill(type.brandColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                }
            Text(type.displayName)
                .foregroundColor(.primary)
            Spacer()
            if isLoading {
                ProgressView()
            }
        }
    }

    private func addGmailAccount() {
        isAddingGmail = true
        errorMessage = nil

        Task {
            do {
                try await accountManager.addGmailAccount()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isAddingGmail = false
        }
    }

    private func addOutlookAccount() {
        isAddingOutlook = true
        errorMessage = nil

        Task {
            do {
                try await accountManager.addOutlookAccount()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isAddingOutlook = false
        }
    }
}
