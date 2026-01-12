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
        count = keptThreadIds().count
    }

    func isKept(_ threadId: String) -> Bool {
        guard let context = modelContext else { return false }
        let descriptor = FetchDescriptor<KeptThread>(
            predicate: #Predicate { $0.threadId == threadId }
        )
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    func keptThreadIds() -> Set<String> {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<KeptThread>()
        guard let threads = try? context.fetch(descriptor) else { return [] }
        return Set(threads.map(\.threadId))
    }

    func addKept(_ threadId: String) {
        guard let context = modelContext else { return }
        guard !isKept(threadId) else { return }
        let keptThread = KeptThread(threadId: threadId)
        context.insert(keptThread)
        try? context.save()
        updateCount()
    }

    func removeKept(_ threadId: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<KeptThread>(
            predicate: #Predicate { $0.threadId == threadId }
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
}
