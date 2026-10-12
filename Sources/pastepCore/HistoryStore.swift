import Foundation

public protocol HistoryPersisting: AnyObject {
    func load() -> [ClipboardEntry]
    func save(_ entries: [ClipboardEntry]) throws
}

/// クリップボード履歴。メインスレッドからのみ使う。
/// 保存は `saveDelay` 秒ぶんまとめてから行い、終了時は `flush()` で書き出す。
public final class HistoryStore {
    public static let defaultMaxEntries = 20
    /// これより大きいテキストは履歴に残さない（メモリと保存コストを抑えるため）
    public static let defaultMaxContentBytes = 256 * 1024

    public private(set) var entries: [ClipboardEntry]
    public let maxEntries: Int
    public let maxContentBytes: Int

    private let persistence: HistoryPersisting
    private let scheduler: Scheduler
    private let saveDelay: TimeInterval
    private var isDirty = false
    private var isSaveScheduled = false

    public init(
        persistence: HistoryPersisting,
        scheduler: Scheduler = MainQueueScheduler(),
        saveDelay: TimeInterval = 1.0,
        maxEntries: Int = HistoryStore.defaultMaxEntries,
        maxContentBytes: Int = HistoryStore.defaultMaxContentBytes
    ) {
        self.persistence = persistence
        self.scheduler = scheduler
        self.saveDelay = saveDelay
        self.maxEntries = maxEntries
        self.maxContentBytes = maxContentBytes
        self.entries = []

        // 保存データが壊れていても上限・重複・サイズ制限を満たす状態に整える
        for entry in persistence.load() where accepts(entry) && !entries.contains(entry) {
            entries.append(entry)
            if entries.count == maxEntries { break }
        }
    }

    /// 履歴の先頭に追加する。同じ内容は先頭へ移動。
    /// - Returns: 履歴が変化したら true（空・サイズ超過・既に先頭なら false）
    @discardableResult
    public func add(_ entry: ClipboardEntry) -> Bool {
        guard accepts(entry) else { return false }
        if entries.first == entry { return false }

        entries.removeAll { $0 == entry }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        scheduleSave()
        return true
    }

    /// 未保存の変更があれば即座に書き出す。失敗した場合は次回に再試行する。
    public func flush() {
        guard isDirty else { return }
        do {
            try persistence.save(entries)
            isDirty = false
        } catch {
            logError("履歴の保存に失敗しました: \(error)")
        }
    }

    private func accepts(_ entry: ClipboardEntry) -> Bool {
        !entry.content.isEmpty && entry.content.utf8.count <= maxContentBytes
    }

    private func scheduleSave() {
        isDirty = true
        guard !isSaveScheduled else { return }
        isSaveScheduled = true
        scheduler.schedule(after: saveDelay) { [weak self] in
            self?.isSaveScheduled = false
            self?.flush()
        }
    }
}
