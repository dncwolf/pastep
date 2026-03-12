import Testing
import AppKit
@testable import pastepCore

final class MockPasteboard: PasteboardProtocol {
    private var _changeCount: Int = 0
    private var _string: String? = nil
    private var _urls: [URL]? = nil

    var changeCount: Int { _changeCount }

    func setString(_ string: String) {
        _string = string
        _urls = nil
        _changeCount += 1
    }

    func setURLs(_ urls: [URL]) {
        _urls = urls
        _string = nil
        _changeCount += 1
    }

    func clearContents() {
        _string = nil
        _urls = nil
        _changeCount += 1
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        guard dataType == .string else { return nil }
        return _string
    }

    func readObjects(forClasses classArray: [AnyClass], options: [NSPasteboard.ReadingOptionKey: Any]?) -> [Any]? {
        guard let urls = _urls else { return nil }
        return urls as [Any]
    }
}

@Suite(.serialized) struct ClipboardMonitorTests {
    let pasteboard: MockPasteboard
    let store: HistoryStore
    let monitor: ClipboardMonitor

    init() {
        pasteboard = MockPasteboard()
        let defaults = UserDefaults(suiteName: "monitor_test_\(UUID().uuidString)")!
        store = HistoryStore(defaults: defaults)
        monitor = ClipboardMonitor(store: store, pasteboard: pasteboard)
    }

    @Test func poll_noChange_doesNotAdd() {
        monitor.poll()
        #expect(store.entries.count == 0)
    }

    @Test func poll_textChange_addsText() {
        pasteboard.setString("hello")
        monitor.poll()
        #expect(store.entries.count == 1)
        #expect(store.entries[0].type == .text)
    }

    @Test func poll_textContentMatches() {
        pasteboard.setString("test content")
        monitor.poll()
        #expect(store.entries[0].content == "test content")
    }

    @Test func poll_filePathChange_addsFilePath() {
        let url = URL(fileURLWithPath: "/tmp/testfile.txt")
        pasteboard.setURLs([url])
        monitor.poll()
        #expect(store.entries.count == 1)
        #expect(store.entries[0].type == .filePath)
    }

    @Test func poll_emptyString_ignored() {
        pasteboard.setString("")
        monitor.poll()
        #expect(store.entries.count == 0)
    }

    @Test func poll_multipleChanges() {
        pasteboard.setString("first")
        monitor.poll()
        pasteboard.clearContents()
        pasteboard.setString("second")
        monitor.poll()
        #expect(store.entries.count == 2)
    }

    @Test func poll_sameContent_deduplicated() {
        pasteboard.setString("same")
        monitor.poll()
        pasteboard.clearContents()
        pasteboard.setString("same")
        monitor.poll()
        #expect(store.entries.count == 1)
    }
}
