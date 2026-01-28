//
//  EmailListView.swift
//  Sweep
//

import SwiftUI
import UIKit

struct EmailListView: View {
    @EnvironmentObject var viewModel: EmailListViewModel
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var keptStore = KeptThreadsStore.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var selectedThread: EmailThread?
    @State private var showingKeptSheet = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                if colorScheme == .dark {
                    Color(hex: 0x030303)
                        .ignoresSafeArea()
                    RadialGradient(
                        colors: [Color(hex: 0x1a1a1a), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 500
                    )
                    .ignoresSafeArea()
                }
                Group {
                    if viewModel.isLoading && viewModel.threads.isEmpty {
                        loadingView
                    } else if viewModel.error != nil {
                        errorView
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
                ToolbarItem(placement: .topBarLeading) {
                    if keptStore.count > 0 {
                        Button {
                            showingKeptSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(keptStore.count)")
                                    .fontWeight(.medium)
                            }
                        }
                        .sheet(isPresented: $showingKeptSheet) {
                            KeptEmailsSheet()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .background(.clear)
        }
        .sheet(item: $selectedThread) { thread in
            EmailDetailView(thread: thread)
        }
        .onChange(of: selectedThread) { _, newValue in
            viewModel.isDetailSheetOpen = newValue != nil
        }
        .toast(
            isPresented: $viewModel.showSkippedProcessingToast,
            message: "Emails weren't processed while viewing details"
        )
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

    private var errorView: some View {
        GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView {
                    Label("Unable to Load", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(viewModel.error?.localizedDescription ?? "Something went wrong")
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
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
                    content: EmailRowView(thread: thread, snippetLines: appState.snippetLines, showAccountIndicator: accountManager.hasMultipleAccounts),
                    preview: { EmailPreviewView(thread: thread) },
                    menu: { makeMenu(for: thread) },
                    onPreviewTap: { selectedThread = thread }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Color.gray.opacity(0.2))
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
        .scrollContentBackground(.hidden)
    }
}
