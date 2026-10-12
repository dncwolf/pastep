import Foundation

/// クリップボード履歴（最新が先頭）。メインスレッドからのみ使う。
/// 変更は1秒まとめてから JSON ファイルへ保存し、終了時は `save()` で書き出す。
final class History {
    static let maxEntries = 20
    /// これより大きいテキストは残さない（メモリと保存コストを抑えるため）
    static let maxBytes = 256 * 1024
    static let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("pastep/history.json")
    static let legacyKey = "clipboard_history"

    private(set) var entries: [ClipboardEntry] = []
    private let fileURL: URL
    private var isDirty = false
    private var isSaveScheduled = false

    init(fileURL: URL = defaultURL, legacyDefaults: UserDefaults? = nil) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL) {
            entries = Self.decode(data)
        } else if let data = legacyDefaults?.data(forKey: Self.legacyKey) {
            // 旧バージョン（UserDefaults 保存）からの移行。書き出せたときだけ旧データを消す
            entries = Self.decode(data)
            isDirty = true
            if save() { legacyDefaults?.removeObject(forKey: Self.legacyKey) }
        }
    }

    /// 先頭に追加する。同じ内容は先頭へ移動。空・サイズ超過は無視。
    func add(_ entry: ClipboardEntry) {
        guard !entry.content.isEmpty, entry.content.utf8.count <= Self.maxBytes, entries.first != entry else { return }
        entries.removeAll { $0 == entry }
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(Self.maxEntries))

        isDirty = true
        guard !isSaveScheduled else { return }
        isSaveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isSaveScheduled = false
            self?.save()
        }
    }

    /// 未保存の変更を書き出す。失敗したら次の変更か終了時に再試行する。
    @discardableResult
    func save() -> Bool {
        guard isDirty else { return true }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
            // クリップボードの中身なので本人以外は読めないようにする
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            isDirty = false
            return true
        } catch {
            NSLog("[pastep] 履歴の保存に失敗しました: \(error)")
            return false
        }
    }

    private static func decode(_ data: Data) -> [ClipboardEntry] {
        Array(((try? JSONDecoder().decode([ClipboardEntry].self, from: data)) ?? []).prefix(maxEntries))
    }
}
