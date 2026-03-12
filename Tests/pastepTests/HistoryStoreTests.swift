import Testing
import Foundation
@testable import pastepCore

@Suite struct HistoryStoreTests {
    let store: HistoryStore
    let suiteName: String

    init() {
        suiteName = "test_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        store = HistoryStore(defaults: defaults)
    }

    @Test func add_firstEntry() {
        store.add(ClipboardEntry(content: "hello", type: .text))
        #expect(store.entries.count == 1)
    }

    @Test func add_prependsToFront() {
        store.add(ClipboardEntry(content: "first", type: .text))
        store.add(ClipboardEntry(content: "second", type: .text))
        #expect(store.entries[0].content == "second")
    }

    @Test func add_duplicateText_movesToFront() {
        store.add(ClipboardEntry(content: "A", type: .text))
        store.add(ClipboardEntry(content: "B", type: .text))
        store.add(ClipboardEntry(content: "A", type: .text))
        #expect(store.entries[0].content == "A")
        #expect(store.entries.count == 2)
    }

    @Test func add_duplicateFilePath_movesToFront() {
        store.add(ClipboardEntry(content: "/tmp/file.txt", type: .filePath))
        store.add(ClipboardEntry(content: "/tmp/other.txt", type: .filePath))
        store.add(ClipboardEntry(content: "/tmp/file.txt", type: .filePath))
        #expect(store.entries[0].content == "/tmp/file.txt")
        #expect(store.entries.count == 2)
    }

    @Test func add_maxEntriesLimit() {
        for i in 0..<20 {
            store.add(ClipboardEntry(content: "item\(i)", type: .text))
        }
        #expect(store.entries.count == 20)
    }

    @Test func add_21stEntry_dropsOldest() {
        for i in 0..<20 {
            store.add(ClipboardEntry(content: "item\(i)", type: .text))
        }
        store.add(ClipboardEntry(content: "item20", type: .text))
        #expect(store.entries.count == 20)
        #expect(store.entries[0].content == "item20")
        #expect(!store.entries.contains(where: { $0.content == "item0" }))
    }

    @Test func persistence_saveAndLoad() {
        store.add(ClipboardEntry(content: "persistent", type: .text))
        let defaults = UserDefaults(suiteName: suiteName)!
        let store2 = HistoryStore(defaults: defaults)
        #expect(store2.entries.count == 1)
        #expect(store2.entries[0].content == "persistent")
    }

    @Test func persistence_emptyOnFirstRun() {
        #expect(store.entries.isEmpty)
    }

    @Test func persistence_corruptedDataIgnored() {
        let defaults = UserDefaults(suiteName: "corrupt_\(UUID().uuidString)")!
        defaults.set(Data([0xFF, 0xFE, 0x00]), forKey: "clipboard_history")
        let store2 = HistoryStore(defaults: defaults)
        #expect(store2.entries.isEmpty)
    }
}
