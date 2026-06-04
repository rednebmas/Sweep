//
//  RecipientSummaryView.swift
//  Sweep
//

import SwiftUI

struct RecipientSummaryView: View {
    let label: String
    let participants: [EmailParticipant]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(names)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
    }

    private var names: String {
        participants.map(\.displayName).joined(separator: ", ")
    }
}
