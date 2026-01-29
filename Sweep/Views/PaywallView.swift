//
//  PaywallView.swift
//  Sweep

import SwiftUI

struct PaywallView: View {
    @ObservedObject private var storeService = StoreService.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            appHeader

            trialEndedMessage

            priceSection

            purchaseButton

            restoreButton

            Spacer()

            errorView
        }
        .padding(32)
    }

    private var appHeader: some View {
        VStack(spacing: 12) {
            Image("AppIcon60x60")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 4)

            Text("Sweep")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }

    private var trialEndedMessage: some View {
        VStack(spacing: 8) {
            Text("Your trial has ended")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Unlock Sweep to continue managing your inbox")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var priceSection: some View {
        VStack(spacing: 4) {
            Text("$4.99")
                .font(.system(size: 44, weight: .bold))

            Text("One-time purchase")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var purchaseButton: some View {
        Button {
            Task { await storeService.purchase() }
        } label: {
            Group {
                if storeService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Unlock Sweep")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(storeService.isLoading)
    }

    private var restoreButton: some View {
        Button {
            Task { await storeService.restorePurchases() }
        } label: {
            Text("Restore Purchase")
                .font(.subheadline)
        }
        .disabled(storeService.isLoading)
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = storeService.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    PaywallView()
}
