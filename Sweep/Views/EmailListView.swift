//
//  EmailListView.swift
//  Sweep
//

import SwiftUI
import UIKit

struct EmailListView: View {
    @EnvironmentObject var viewModel: EmailListViewModel
    @ObservedObject private var appState = AppState.shared
    @State private var selectedThread: EmailThread?
    @State private var showingKeptSheet = false

    private var keptThreads: [EmailThread] {
        viewModel.threads.filter { $0.isKept }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !keptThreads.isEmpty {
                    keptBanner
                }
                Group {
                    if viewModel.isLoading && viewModel.threads.isEmpty {
                        loadingView
                    } else if viewModel.threads.isEmpty {
                        emptyView
                    } else {
                        emailList
                    }
                }
            }
            .navigationTitle("Sweep")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .sheet(item: $selectedThread) { thread in
            EmailDetailView(thread: thread)
        }
        .onAppear {
            if viewModel.threads.isEmpty {
                Task { await viewModel.loadThreads() }
            }
        }
    }

    private var loadingView: some View {
        ProgressView("Loading emails...")
    }

    private var emptyView: some View {
        GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView(
                    "No emails",
                    systemImage: "tray",
                    description: Text("You're all caught up!")
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var keptBanner: some View {
        VStack(spacing: 0) {
            Button {
                showingKeptSheet = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(keptThreads.count) kept")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
            }
            .buttonStyle(.plain)
            Divider()
        }
        .sheet(isPresented: $showingKeptSheet) {
            KeptEmailsSheet(threads: keptThreads, onSelect: { selectedThread = $0 })
        }
    }

    private func makeMenu(for thread: EmailThread) -> UIMenu {
        var actions: [UIAction] = [
            UIAction(title: "Block Sender", image: UIImage(systemName: "nosign")) { _ in
                Task { await viewModel.blockSender(thread) }
            },
            UIAction(title: "Mark as Spam", image: UIImage(systemName: "exclamationmark.triangle")) { _ in
                Task { await viewModel.markAsSpam(thread) }
            }
        ]
        if thread.unsubscribeURL != nil {
            actions.append(UIAction(title: "Unsubscribe", image: UIImage(systemName: "bell.slash")) { _ in
                viewModel.unsubscribe(thread)
            })
        }
        return UIMenu(children: actions)
    }

    private var emailList: some View {
        List {
            ForEach(viewModel.threads) { thread in
                ContextMenuWrapper(
                    content: EmailRowView(thread: thread, snippetLines: appState.snippetLines),
                    preview: { EmailPreviewView(thread: thread) },
                    menu: { makeMenu(for: thread) },
                    onPreviewTap: { selectedThread = thread }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparatorTint(Color.gray.opacity(0.3))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        viewModel.toggleKeep(thread)
                    } label: {
                        Label("Keep", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
                .onTapGesture {
                    selectedThread = thread
                }
            }
        }
        .listStyle(.plain)
    }
}
