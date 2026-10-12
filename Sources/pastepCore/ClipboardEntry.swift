import Foundation

public enum EntryType: String, Codable {
    case text
    case filePath
}

public struct ClipboardEntry: Codable, Equatable {
    public let id: UUID
    public let content: String
    public let type: EntryType
    public let createdAt: Date

    public init(content: String, type: EntryType, id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.type = type
        self.createdAt = createdAt
    }

    /// 重複判定は内容と種別のみ（id・日時は無視）
    public static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.type == rhs.type && lhs.content == rhs.content
    }

    /// メニュー表示用の1行タイトル。
    /// テキストは空白・改行を1つの空白にまとめ、`maxLength` 文字（書記素単位）を超えたら末尾を「…」にする。
    /// ファイルパスはファイル名を返す。
    public func title(maxLength: Int) -> String {
        switch type {
        case .filePath:
            let name = URL(fileURLWithPath: content).lastPathComponent
            return name.isEmpty ? content : name
        case .text:
            let (flattened, truncated) = Self.flatten(content, limit: maxLength)
            if flattened.isEmpty { return Self.whitespaceOnlyTitle }
            return truncated ? flattened + "…" : flattened
        }
    }

    /// ツールチップ用。ファイルパスはフルパス、テキストは先頭 `maxLength` 文字まで。
    public func toolTip(maxLength: Int) -> String {
        switch type {
        case .filePath:
            return content
        case .text:
            guard content.count > maxLength else { return content }
            return String(content.prefix(maxLength)) + "…"
        }
    }

    static let whitespaceOnlyTitle = "（空白のみ）"

    /// 巨大なテキストでも先頭 `limit` 文字ぶんだけ走査する。
    private static func flatten(_ text: String, limit: Int) -> (String, Bool) {
        var result = ""
        var count = 0
        var pendingSpace = false
        for character in text {
            if character.isWhitespace || character.isNewline {
                pendingSpace = count > 0
                continue
            }
            if pendingSpace {
                // 区切りの空白の直後で切れるなら空白を付けずに打ち切る
                if count + 1 >= limit { return (result, true) }
                result.append(" ")
                count += 1
                pendingSpace = false
            }
            if count == limit { return (result, true) }
            result.append(character)
            count += 1
        }
        return (result, false)
    }
}
