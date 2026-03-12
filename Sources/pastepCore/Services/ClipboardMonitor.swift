import AppKit
import Foundation

public protocol PasteboardProtocol: AnyObject {
    var changeCount: Int { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func readObjects(forClasses classArray: [AnyClass], options: [NSPasteboard.ReadingOptionKey: Any]?) -> [Any]?
}

extension NSPasteboard: PasteboardProtocol {}

public class ClipboardMonitor {
    private let store: HistoryStore
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard: PasteboardProtocol

    public convenience init(store: HistoryStore) {
        self.init(store: store, pasteboard: NSPasteboard.general)
    }

    init(store: HistoryStore, pasteboard: PasteboardProtocol) {
        self.store = store
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let entry = ClipboardEntry(content: text, type: .text)
            store.add(entry)
        } else if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                  let url = urls.first {
            let entry = ClipboardEntry(content: url.path, type: .filePath)
            store.add(entry)
        }
    }
}
