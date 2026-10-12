import Foundation

/// 履歴を JSON ファイルに保存する。
/// 旧バージョンの UserDefaults("clipboard_history") にデータがあれば初回読み込み時に移行する。
public final class FileHistoryPersistence: HistoryPersisting {
    public static let legacyDefaultsKey = "clipboard_history"

    public let fileURL: URL
    private let legacyDefaults: UserDefaults?

    public init(fileURL: URL, legacyDefaults: UserDefaults? = nil) {
        self.fileURL = fileURL
        self.legacyDefaults = legacyDefaults
    }

    /// ~/Library/Application Support/pastep/history.json
    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("pastep", isDirectory: true).appendingPathComponent("history.json")
    }

    public func load() -> [ClipboardEntry] {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            return Self.decode(data) ?? []
        }
        return migrateFromLegacyDefaults()
    }

    public func save(_ entries: [ClipboardEntry]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entries)
        try data.write(to: fileURL, options: .atomic)
        // クリップボードの中身なので本人以外は読めないようにする
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func migrateFromLegacyDefaults() -> [ClipboardEntry] {
        guard
            let defaults = legacyDefaults,
            let data = defaults.data(forKey: Self.legacyDefaultsKey),
            let entries = Self.decode(data)
        else { return [] }

        // ファイルへ書き出せたときだけ旧データを消す（失敗時は次回また移行を試みる）
        do {
            try save(entries)
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
        } catch {
            logError("旧履歴の移行に失敗しました: \(error)")
        }
        return entries
    }

    private static func decode(_ data: Data) -> [ClipboardEntry]? {
        try? JSONDecoder().decode([ClipboardEntry].self, from: data)
    }
}
