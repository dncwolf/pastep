import Testing
import Foundation
@testable import pastepCore

@Suite struct HistoryStoreTests {

    // MARK: - 追加・並び順

    @Test func startsEmpty() {
        #expect(makeStore().entries.isEmpty)
    }

    @Test func add_prependsToFront() {
        let store = makeStore()
        store.add(text("first"))
        store.add(text("second"))
        #expect(store.entries.map(\.content) == ["second", "first"])
    }

    @Test func add_duplicateMovesToFrontWithoutGrowing() {
        let store = makeStore()
        store.add(text("A"))
        store.add(text("B"))
        store.add(text("C"))
        #expect(store.add(text("B")))
        #expect(store.entries.map(\.content) == ["B", "C", "A"])
    }

    @Test func add_duplicateFilePathMovesToFront() {
        let store = makeStore()
        store.add(file("/tmp/file.txt"))
        store.add(file("/tmp/other.txt"))
        store.add(file("/tmp/file.txt"))
        #expect(store.entries.map(\.content) == ["/tmp/file.txt", "/tmp/other.txt"])
    }

    @Test func add_sameContentDifferentTypeAreDistinct() {
        let store = makeStore()
        store.add(text("/tmp/a"))
        store.add(file("/tmp/a"))
        #expect(store.entries.count == 2)
    }

    @Test func add_sameAsFrontIsNoChange() {
        let scheduler = ManualScheduler()
        let store = makeStore(scheduler: scheduler)
        store.add(text("A"))
        scheduler.runAll()
        #expect(store.add(text("A")) == false)
        #expect(scheduler.pending.isEmpty)
    }

    @Test func add_keepsAtMostMaxEntriesDroppingOldest() {
        let store = makeStore()
        for i in 0..<25 {
            store.add(text("item\(i)"))
        }
        #expect(store.entries.count == 20)
        #expect(store.entries.first?.content == "item24")
        #expect(store.entries.last?.content == "item5")
    }

    @Test func add_customMaxEntries() {
        let store = makeStore(maxEntries: 3)
        ["a", "b", "c", "d"].forEach { store.add(text($0)) }
        #expect(store.entries.map(\.content) == ["d", "c", "b"])
    }

    // MARK: - 受け付けない内容

    @Test func add_emptyContentIsRejected() {
        let store = makeStore()
        #expect(store.add(text("")) == false)
        #expect(store.add(file("")) == false)
        #expect(store.entries.isEmpty)
    }

    @Test func add_contentOverByteLimitIsRejected() {
        let store = makeStore(maxContentBytes: 10)
        #expect(store.add(text(String(repeating: "a", count: 11))) == false)
        #expect(store.entries.isEmpty)
    }

    @Test func add_contentAtByteLimitIsAccepted() {
        let store = makeStore(maxContentBytes: 10)
        #expect(store.add(text(String(repeating: "a", count: 10))))
    }

    @Test func add_byteLimitCountsUTF8Bytes() {
        // 「あ」は UTF-8 で3バイト。4文字 = 12バイト
        let store = makeStore(maxContentBytes: 10)
        #expect(store.add(text("あああ")))      // 9 bytes
        #expect(store.add(text("ああああ")) == false) // 12 bytes
    }

    @Test func defaultByteLimitIs256KB() {
        let store = makeStore()
        #expect(store.add(text(String(repeating: "a", count: 256 * 1024))))
        #expect(store.add(text(String(repeating: "b", count: 256 * 1024 + 1))) == false)
    }

    @Test func rejectedEntryDoesNotDisturbExistingOrder() {
        let store = makeStore(maxContentBytes: 5)
        store.add(text("a"))
        store.add(text("b"))
        store.add(text("toolong"))
        #expect(store.entries.map(\.content) == ["b", "a"])
    }

    // MARK: - 保存（まとめ書き）

    @Test func save_isDeferredAndCoalesced() {
        let persistence = InMemoryPersistence()
        let scheduler = ManualScheduler()
        let store = makeStore(persistence, scheduler: scheduler)

        store.add(text("a"))
        store.add(text("b"))
        store.add(text("c"))
        #expect(persistence.saveCount == 0)
        #expect(scheduler.pending.count == 1)
        #expect(scheduler.delays == [1.0])

        scheduler.runAll()
        #expect(persistence.saveCount == 1)
        #expect(persistence.stored.map(\.content) == ["c", "b", "a"])
    }

    @Test func save_newChangeAfterSaveSchedulesAgain() {
        let persistence = InMemoryPersistence()
        let scheduler = ManualScheduler()
        let store = makeStore(persistence, scheduler: scheduler)

        store.add(text("a"))
        scheduler.runAll()
        store.add(text("b"))
        #expect(scheduler.pending.count == 1)
        scheduler.runAll()
        #expect(persistence.saveCount == 2)
        #expect(persistence.stored.map(\.content) == ["b", "a"])
    }

    @Test func flush_writesImmediatelyAndScheduledSaveBecomesNoOp() {
        let persistence = InMemoryPersistence()
        let scheduler = ManualScheduler()
        let store = makeStore(persistence, scheduler: scheduler)

        store.add(text("a"))
        store.flush()
        #expect(persistence.saveCount == 1)
        scheduler.runAll()
        #expect(persistence.saveCount == 1)
    }

    @Test func flush_withoutChangesDoesNothing() {
        let persistence = InMemoryPersistence([text("x")])
        let store = makeStore(persistence)
        store.flush()
        #expect(persistence.saveCount == 0)
    }

    @Test func flush_failureIsRetriedOnNextFlush() {
        let persistence = InMemoryPersistence()
        let scheduler = ManualScheduler()
        let store = makeStore(persistence, scheduler: scheduler)

        store.add(text("a"))
        persistence.failNextSave = true
        scheduler.runAll()
        #expect(persistence.saveCount == 0)

        store.flush()
        #expect(persistence.saveCount == 1)
        #expect(persistence.stored.map(\.content) == ["a"])
    }

    @Test func scheduledSaveAfterStoreIsGoneDoesNotCrash() {
        let persistence = InMemoryPersistence()
        let scheduler = ManualScheduler()
        do {
            let store = makeStore(persistence, scheduler: scheduler)
            store.add(text("a"))
        }
        scheduler.runAll()
        #expect(persistence.saveCount == 0)
    }

    // MARK: - 読み込み

    @Test func load_restoresSavedOrder() {
        let persistence = InMemoryPersistence([text("new"), text("old")])
        #expect(makeStore(persistence).entries.map(\.content) == ["new", "old"])
    }

    @Test func load_sanitizesBrokenData() {
        let persistence = InMemoryPersistence([
            text("a"),
            text(""),
            text("a"),
            text(String(repeating: "x", count: 11)),
            file("/tmp/f"),
            text("b"),
            text("c"),
        ])
        let store = makeStore(persistence, maxEntries: 3, maxContentBytes: 10)
        #expect(store.entries.map(\.content) == ["a", "/tmp/f", "b"])
    }

    @Test func load_doesNotTriggerSave() {
        let persistence = InMemoryPersistence([text("a")])
        let scheduler = ManualScheduler()
        _ = makeStore(persistence, scheduler: scheduler)
        #expect(scheduler.pending.isEmpty)
        #expect(persistence.saveCount == 0)
    }
}
