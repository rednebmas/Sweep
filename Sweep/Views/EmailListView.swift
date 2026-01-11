//
//  EmailListView.swift
//  Sweep
//

import SwiftUI

struct EmailListView: View {
    @EnvironmentObject var viewModel: EmailListViewModel
    @ObservedObject private var appState = AppState.shared
    @State private var selectedThread: EmailThread?
    @State private var showingActionSheet = false
    @State private var actionSheetThread: EmailThread?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.threads.isEmpty {
                    loadingView
                } else if viewModel.threads.isEmpty {
                    emptyView
                } else {
                    emailList
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
        .confirmationDialog(
            actionSheetThread?.cleanSubject ?? "Actions",
            isPresented: $showingActionSheet,
            titleVisibility: .visible,
            presenting: actionSheetThread
        ) { thread in
            Button("Block Sender") {
                Task { await viewModel.blockSender(thread) }
            }
            Button("Mark as Spam") {
                Task { await viewModel.markAsSpam(thread) }
            }
            Button("Unsubscribe") {
                Task { await viewModel.unsubscribe(thread) }
            }
            Button("Cancel", role: .cancel) {}
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
                    .onTapGesture {
                        selectedThread = thread
                    }
                    .onLongPressGesture {
                        actionSheetThread = thread
                        showingActionSheet = true
                    }
            }
        }
        .listStyle(.plain)
    }
}
