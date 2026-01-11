//
//  EmailPreviewView.swift
//  Sweep
//

import SwiftUI
import UIKit

struct EmailPreviewView: View {
    let thread: EmailThread
    @State private var emailBody: String?
    @State private var isLoading = true
    private let initTime = Date()

    init(thread: EmailThread) {
        self.thread = thread
        print("[Preview] Init for thread: \(thread.id)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            bodyContent
        }
        .padding()
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else if let body = emailBody, !body.isEmpty {
                HTMLView(html: body)
            } else {
                Text(thread.snippet)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func loadBody() async {
        do {
            emailBody = try await GmailService.shared.fetchEmailBody(thread.id)
        } catch {
            emailBody = nil
        }
        isLoading = false
        let elapsed = Date().timeIntervalSince(initTime) * 1000
        print("[Preview] Loaded in \(Int(elapsed))ms")
    }
}
