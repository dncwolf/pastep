import Foundation
@testable import pastepCore

/// 予約された処理を記録し、テストから明示的に実行する
final class ManualScheduler: Scheduler {
    private(set) var pending: [(delay: TimeInterval, work: () -> Void)] = []

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        pending.append((delay, work))
    }

    var delays: [TimeInterval] { pending.map(\.delay) }

    func runAll() {
        let works = pending
        pending.removeAll()
        works.forEach { $0.work() }
    }
}

final class InMemoryPersistence: HistoryPersisting {
    var stored: [ClipboardEntry]
    private(set) var saveCount = 0
    var failNextSave = false

    struct SaveError: Error {}

    init(_ stored: [ClipboardEntry] = []) {
        self.stored = stored
    }

    func load() -> [ClipboardEntry] { stored }

    func save(_ entries: [ClipboardEntry]) throws {
        if failNextSave {
            failNextSave = false
            throw SaveError()
        }
        saveCount += 1
        stored = entries
    }
}

final class MockPasteboard: PasteboardReading {
    private(set) var changeCount = 0
    private var string: String?
    private var fileURLs: [URL] = []
    private(set) var readCount = 0

    func set(string: String?, fileURLs: [URL] = []) {
        self.string = string
        self.fileURLs = fileURLs
        changeCount += 1
    }

    func readString() -> String? {
        readCount += 1
        return string
    }

    func readFileURLs() -> [URL] {
        readCount += 1
        return fileURLs
    }
}

func text(_ content: String) -> ClipboardEntry {
    ClipboardEntry(content: content, type: .text)
}

func file(_ path: String) -> ClipboardEntry {
    ClipboardEntry(content: path, type: .filePath)
}

func makeStore(
    _ persistence: InMemoryPersistence = InMemoryPersistence(),
    scheduler: ManualScheduler = ManualScheduler(),
    maxEntries: Int = HistoryStore.defaultMaxEntries,
    maxContentBytes: Int = HistoryStore.defaultMaxContentBytes
) -> HistoryStore {
    HistoryStore(
        persistence: persistence,
        scheduler: scheduler,
        maxEntries: maxEntries,
        maxContentBytes: maxContentBytes
    )
}

/// テストごとに使い捨てる一時ディレクトリ
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("pastep-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
