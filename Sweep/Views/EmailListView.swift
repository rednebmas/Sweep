//
//  EmailListView.swift
//  Sweep
//

import SwiftUI

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
        .sheet(isPresented: $showingKeptSheet) {
            KeptEmailsSheet(threads: keptThreads, onSelect: { selectedThread = $0 })
        }
    }

    private var emailList: some View {
        List {
            ForEach(viewModel.threads) { thread in
                EmailRowView(thread: thread, snippetLines: appState.snippetLines)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            viewModel.toggleKeep(thread)
                        } label: {
                            Label("Keep", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .contextMenu {
                        Button {
                            Task { await viewModel.blockSender(thread) }
                        } label: {
                            Label("Block Sender", systemImage: "nosign")
                        }
                        Button {
                            Task { await viewModel.markAsSpam(thread) }
                        } label: {
                            Label("Mark as Spam", systemImage: "exclamationmark.triangle")
                        }
                        if thread.unsubscribeURL != nil {
                            Button {
                                viewModel.unsubscribe(thread)
                            } label: {
                                Label("Unsubscribe", systemImage: "bell.slash")
                            }
                        }
                    } preview: {
                        EmailPreviewView(thread: thread)
                    }
                    .onTapGesture {
                        selectedThread = thread
                    }
            }
        }
        .listStyle(.plain)
    }
}
