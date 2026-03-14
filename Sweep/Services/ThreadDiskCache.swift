//
//  ThreadDiskCache.swift
//  Sweep

import Foundation

enum ThreadDiskCache {
    private static let queue = DispatchQueue(label: "ThreadDiskCache")

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appending(path: "thread-cache.json")
    }

    static func load() -> [EmailThread]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([EmailThread].self, from: data)
    }

    static func save(_ threads: [EmailThread]) {
        queue.async {
            guard let data = try? JSONEncoder().encode(threads) else { return }
            let dir = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    static func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
