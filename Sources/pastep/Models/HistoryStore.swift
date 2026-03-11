import Foundation
import Combine

class HistoryStore: ObservableObject {
    @Published var entries: [ClipboardEntry] = []

    private let maxEntries = 20
    private let defaultsKey = "clipboard_history"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        load()
    }

    func add(_ entry: ClipboardEntry) {
        // 重複除去（同じ content + type のエントリを削除）
        entries.removeAll { $0 == entry }
        // 先頭に挿入
        entries.insert(entry, at: 0)
        // 20件超過分を末尾から削除
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    private func save() {
        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let loaded = try? decoder.decode([ClipboardEntry].self, from: data)
        else { return }
        entries = loaded
    }
}
