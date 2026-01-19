//
//  AccountRowView.swift
//  Sweep

import SwiftUI

struct AccountRowView: View {
    let account: EmailAccount
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AccountIndicatorView(providerType: account.providerType)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.email)
                    .font(.body)
                Text(account.providerType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
