//
//  EmailPreviewView.swift
//  Sweep
//

import SwiftUI

struct EmailPreviewView: View {
    let thread: EmailThread
    @State private var emailBody: String?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            bodyContent
        }
        .padding()
        .frame(width: 340, height: 400)
        .task {
            await loadBody()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.cleanSubject)
                .font(.headline)
                .lineLimit(2)
            Text(thread.from)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var bodyContent: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let body = emailBody, !body.isEmpty {
                HTMLView(html: body)
            } else {
                Text(thread.snippet)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadBody() async {
        #if DEBUG
        if MockDataProvider.useMockData {
            emailBody = MockDataProvider.mockEmailBody(for: thread.id)
            isLoading = false
            return
        }
        #endif

        do {
            emailBody = try await GmailService.shared.fetchEmailBody(thread.id)
        } catch {
            emailBody = nil
        }
        isLoading = false
    }
}
