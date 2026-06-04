//
//  ReplyComposerView.swift
//  Sweep
//

import SwiftUI

struct ReplyComposerView: View {
    @StateObject private var viewModel: ReplyComposerViewModel
    private let onSent: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ReplyComposerViewModel, onSent: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSent = onSent
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(viewModel.mode.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .toast(isPresented: $viewModel.showToast, message: viewModel.toastMessage)
                .task { await viewModel.load() }
                .onChange(of: viewModel.didSend) { _, sent in
                    if sent {
                        onSent()
                        dismiss()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingContext {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.loadError {
            errorView(error)
        } else {
            composer
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecipientSummaryView(label: "To", participants: viewModel.to)
            if !viewModel.cc.isEmpty {
                RecipientSummaryView(label: "Cc", participants: viewModel.cc)
            }
            subjectRow
            Divider()
            TextEditor(text: $viewModel.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }

    private var subjectRow: some View {
        HStack(spacing: 6) {
            Text("Subject")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(viewModel.subject)
                .font(.subheadline)
                .lineLimit(1)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isSending {
                ProgressView()
            } else {
                Button("Send") {
                    Task { await viewModel.send() }
                }
                .disabled(!viewModel.canSend)
            }
        }
    }
}
