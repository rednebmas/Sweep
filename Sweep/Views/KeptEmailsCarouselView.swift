//
//  KeptEmailsCarouselView.swift
//  Sweep

import SwiftUI

struct KeptEmailsCarouselView: View {
    let threads: [EmailThread]
    let onSeeAll: () -> Void
    let onTap: (EmailThread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            scrollCards
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var header: some View {
        HStack {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundColor(.green)
            Text("KEPT")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .tracking(0.5)
            Spacer()
        }
    }

    private var scrollCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(threads.prefix(10)) { thread in
                    cardView(thread)
                        .onTapGesture { onTap(thread) }
                }
                seeAllCard
            }
        }
    }

    private func cardView(_ thread: EmailThread) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(thread.from)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(thread.cleanSubject)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(width: 150, alignment: .topLeading)
        .padding(10)
        .background(Color.green.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var seeAllCard: some View {
        Button(action: onSeeAll) {
            Text("See all kept emails")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 100)
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .cornerRadius(10)
        }
    }
}
