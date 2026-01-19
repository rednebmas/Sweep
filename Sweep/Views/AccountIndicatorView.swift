//
//  AccountIndicatorView.swift
//  Sweep

import SwiftUI

struct AccountIndicatorView: View {
    let providerType: EmailProviderType

    var body: some View {
        Circle()
            .fill(providerType.brandColor)
            .frame(width: 8, height: 8)
    }
}
