//
//  SubscriptionSectionView.swift
//  Sweep

import SwiftUI

struct SubscriptionSectionView: View {
    @ObservedObject private var storeService = StoreService.shared
    @ObservedObject private var trialService = TrialService.shared

    var body: some View {
        Section("Subscription") {
            statusRow
            restoreButton
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if storeService.isPurchased {
            HStack {
                Text("Sweep Unlocked")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        } else {
            HStack {
                Text("Trial")
                Spacer()
                Text("\(trialService.daysRemaining) days remaining")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await storeService.restorePurchases() }
        } label: {
            HStack {
                Text("Restore Purchase")
                if storeService.isLoading {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(storeService.isLoading)
    }
}
