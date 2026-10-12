import Foundation

public protocol PasteboardReading: AnyObject {
    var changeCount: Int { get }
    func readString() -> String?
    /// ファイル URL のみ（Web の URL は含めない）
    func readFileURLs() -> [URL]
}

/// ペーストボードの changeCount をポーリングし、変化があれば履歴に追加する。
/// macOS にはペーストボードの変更通知がないためポーリングは避けられないが、
/// 変化がないときは changeCount を1回読むだけで終わる。
public final class ClipboardWatcher {
    private let pasteboard: PasteboardReading
    private let store: HistoryStore
    private var lastChangeCount: Int
    private var timer: Timer?

    public init(pasteboard: PasteboardReading, store: HistoryStore) {
        self.pasteboard = pasteboard
        self.store = store
        // 起動時に既にあった内容は履歴に入れない
        self.lastChangeCount = pasteboard.changeCount
    }

    public var isRunning: Bool { timer != nil }

    /// - Parameters:
    ///   - interval: ポーリング間隔
    ///   - tolerance: OS がタイマー起動をまとめられる許容幅（省電力）
    public func start(interval: TimeInterval = 0.5, tolerance: TimeInterval = 0.25, runLoop: RunLoop = .main) {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = tolerance
        // .common: メニュー表示中（イベントトラッキング中）も監視を続ける
        runLoop.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// - Returns: 履歴が変化したら true
    @discardableResult
    public func poll() -> Bool {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return false }
        lastChangeCount = changeCount

        // Finder でのファイルコピーはファイル名の文字列も載るため、ファイル URL を優先する
        if let url = pasteboard.readFileURLs().first {
            return store.add(ClipboardEntry(content: url.path, type: .filePath))
        }
        if let text = pasteboard.readString(), !text.isEmpty {
            return store.add(ClipboardEntry(content: text, type: .text))
        }
        return false
    }
}
