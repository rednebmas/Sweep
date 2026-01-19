//
//  KeptThreadsStore.swift
//  Sweep

import SwiftData
import Foundation
import Combine

@MainActor
class KeptThreadsStore: ObservableObject {
    static let shared = KeptThreadsStore()

    @Published private(set) var count: Int = 0

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    private init() {}

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = container.mainContext
        updateCount()
    }

    private func updateCount() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<KeptThread>()
        count = (try? context.fetchCount(descriptor)) ?? 0
    }

    func isKept(_ threadId: String, accountId: String) -> Bool {
        guard let context = modelContext else { return false }
        let compositeId = "\(accountId):\(threadId)"
        let descriptor = FetchDescriptor<KeptThread>(
            predicate: #Predicate { $0.compositeId == compositeId }
        )
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    func keptThreadIds(for accountId: String) -> Set<String> {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<KeptThread>(
            predicate: #Predicate { $0.accountId == accountId }
        )
        guard let threads = try? context.fetch(descriptor) else { return [] }
        return Set(threads.map(\.threadId))
    }

    func allKeptThreadIds() -> Set<String> {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<KeptThread>()
        guard let threads = try? context.fetch(descriptor) else { return [] }
        return Set(threads.map(\.compositeId))
    }

    func addKept(_ threadId: String, accountId: String) {
        guard let context = modelContext else { return }
        guard !isKept(threadId, accountId: accountId) else { return }
        let keptThread = KeptThread(threadId: threadId, accountId: accountId)
        context.insert(keptThread)
        try? context.save()
        updateCount()
    }

    func removeKept(_ threadId: String, accountId: String) {
        guard let context = modelContext else { return }
        let compositeId = "\(accountId):\(threadId)"
        let descriptor = FetchDescriptor<KeptThread>(
            predicate: #Predicate { $0.compositeId == compositeId }
        )
        guard let threads = try? context.fetch(descriptor) else { return }
        for thread in threads {
            context.delete(thread)
        }
        try? context.save()
        updateCount()
    }

    func clearAll() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<KeptThread>()
        guard let threads = try? context.fetch(descriptor) else { return }
        for thread in threads {
            context.delete(thread)
        }
        try? context.save()
        updateCount()
    }

    func migrateExistingThreads(to accountId: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<KeptThread>(
            predicate: #Predicate { $0.accountId == "" }
        )
        guard let threads = try? context.fetch(descriptor) else { return }
        for thread in threads {
            thread.accountId = accountId
            thread.compositeId = "\(accountId):\(thread.threadId)"
        }
        try? context.save()
    }
}
