import Testing
import AppKit
@testable import pastepCore

@Suite(.serialized) struct ClipboardFlowE2ETests {
    let store: HistoryStore
    let monitor: ClipboardMonitor
    let pasteboard: MockPasteboard
    let suiteName: String

    init() {
        pasteboard = MockPasteboard()
        suiteName = "e2e_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        store = HistoryStore(defaults: defaults)
        monitor = ClipboardMonitor(store: store, pasteboard: pasteboard)
    }

    @Test func copyText_appearsInHistory() {
        pasteboard.setString("hello e2e")
        monitor.poll()
        #expect(store.entries.count == 1)
        #expect(store.entries[0].content == "hello e2e")
    }

    @Test func copyOrder() {
        pasteboard.setString("first")
        monitor.poll()
        pasteboard.clearContents()
        pasteboard.setString("second")
        monitor.poll()
        #expect(store.entries[0].content == "second")
    }

    @Test func copyDuplicate_movesToFront() {
        pasteboard.setString("A")
        monitor.poll()
        pasteboard.clearContents()
        pasteboard.setString("B")
        monitor.poll()
        pasteboard.clearContents()
        pasteboard.setString("A")
        monitor.poll()
        #expect(store.entries.map { $0.content } == ["A", "B"])
    }

    @Test func persistenceAcrossInstances() {
        pasteboard.setString("persistent data")
        monitor.poll()
        let defaults = UserDefaults(suiteName: suiteName)!
        let store2 = HistoryStore(defaults: defaults)
        #expect(store2.entries.count == 1)
        #expect(store2.entries[0].content == "persistent data")
    }

    @Test func maxEntriesEnforced() {
        for i in 0..<21 {
            pasteboard.clearContents()
            pasteboard.setString("item\(i)")
            monitor.poll()
        }
        #expect(store.entries.count == 20)
    }

    @Test func filePathFlow() {
        let url = URL(fileURLWithPath: "/tmp/e2e_test.txt")
        pasteboard.clearContents()
        pasteboard.setURLs([url])
        monitor.poll()
        #expect(store.entries.count == 1)
        #expect(store.entries[0].type == .filePath)
        #expect(store.entries[0].content == "/tmp/e2e_test.txt")
    }
}
