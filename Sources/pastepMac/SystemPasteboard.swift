import AppKit
import pastepCore

/// NSPasteboard のアダプタ。テストでは名前付きの専用ペーストボードを渡す。
public final class SystemPasteboard: PasteboardReading {
    public let pasteboard: NSPasteboard

    public init(_ pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }

    public func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    public func readFileURLs() -> [URL] {
        // 型の確認だけなら中身を読まずに済む
        guard pasteboard.availableType(from: [.fileURL]) != nil else { return [] }
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return (objects as? [URL]) ?? []
    }

    public func write(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        switch entry.type {
        case .filePath:
            pasteboard.writeObjects([URL(fileURLWithPath: entry.content) as NSURL])
        case .text:
            pasteboard.setString(entry.content, forType: .string)
        }
    }
}
