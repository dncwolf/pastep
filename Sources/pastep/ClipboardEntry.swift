import AppKit

enum EntryType: String, Codable {
    case text
    case filePath
}

/// 履歴の1件。旧形式の `id`・`createdAt` は読み込み時に無視される。
struct ClipboardEntry: Codable, Equatable {
    let content: String
    let type: EntryType

    /// メニュー表示用の1行。テキストは空白・改行を1つの空白にまとめて25文字まで、ファイルはファイル名。
    var title: String {
        switch type {
        case .filePath:
            return URL(fileURLWithPath: content).lastPathComponent
        case .text:
            // ponytail: 巨大なテキストでも先頭1000文字だけ見る。それ以降まで空白が続くと「（空白のみ）」になる
            let flat = content.prefix(1000).split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if flat.isEmpty { return "（空白のみ）" }
            return flat.count > 25 ? String(flat.prefix(25)) + "…" : flat
        }
    }

    /// ツールチップ。ファイルはフルパス、テキストは先頭500文字まで。
    var toolTip: String {
        let head = content.prefix(500)
        return type == .filePath || head.endIndex == content.endIndex ? content : String(head) + "…"
    }
}

extension NSPasteboard {
    /// ファイル URL を優先する（Finder はファイル名の文字列も載せるため）。複数ファイルなら先頭のみ。
    func readEntry() -> ClipboardEntry? {
        // 型の確認だけなら中身を読まずに済む
        if availableType(from: [.fileURL]) != nil,
           let url = readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])?.first as? URL {
            return ClipboardEntry(content: url.path, type: .filePath)
        }
        guard let text = string(forType: .string), !text.isEmpty else { return nil }
        return ClipboardEntry(content: text, type: .text)
    }

    func write(_ entry: ClipboardEntry) {
        clearContents()
        switch entry.type {
        case .filePath: writeObjects([URL(fileURLWithPath: entry.content) as NSURL])
        case .text: setString(entry.content, forType: .string)
        }
    }
}
