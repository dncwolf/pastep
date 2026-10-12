import Testing
import Foundation
@testable import pastepCore

@Suite struct ClipboardWatcherTests {
    let pasteboard = MockPasteboard()
    let store = makeStore()

    @Test func contentPresentAtLaunchIsNotRecorded() {
        pasteboard.set(string: "before launch")
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        #expect(watcher.poll() == false)
        #expect(store.entries.isEmpty)
    }

    @Test func noChange_doesNotReadContents() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        watcher.poll()
        watcher.poll()
        #expect(pasteboard.readCount == 0)
    }

    @Test func textCopy_isRecorded() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.set(string: "hello")
        #expect(watcher.poll())
        #expect(store.entries == [text("hello")])
    }

    @Test func fileCopy_isRecordedAsPath() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.set(string: nil, fileURLs: [URL(fileURLWithPath: "/tmp/test file.txt")])
        watcher.poll()
        #expect(store.entries == [file("/tmp/test file.txt")])
    }

    @Test func fileURLTakesPriorityOverString() {
        // Finder はファイル URL と一緒にファイル名の文字列も載せる
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.set(string: "report.pdf", fileURLs: [URL(fileURLWithPath: "/Users/me/report.pdf")])
        watcher.poll()
        #expect(store.entries == [file("/Users/me/report.pdf")])
    }

    @Test func multipleFiles_firstIsRecorded() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.set(string: nil, fileURLs: [URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")])
        watcher.poll()
        #expect(store.entries == [file("/tmp/a")])
    }

    @Test func emptyString_isIgnored() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.set(string: "")
        #expect(watcher.poll() == false)
        #expect(store.entries.isEmpty)
    }

    @Test func unsupportedContent_isIgnored() {
        // 画像などテキストもファイルもない内容
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.set(string: nil)
        #expect(watcher.poll() == false)
        #expect(store.entries.isEmpty)
    }

    @Test func eachChangeIsReadOnlyOnce() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: makeStore(maxContentBytes: 3))
        pasteboard.set(string: "too long")
        watcher.poll()
        let reads = pasteboard.readCount
        watcher.poll()
        watcher.poll()
        #expect(pasteboard.readCount == reads)
    }

    @Test func sequenceOfCopies_keepsNewestFirstWithoutDuplicates() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        for content in ["A", "B", "A", "C"] {
            pasteboard.set(string: content)
            watcher.poll()
        }
        #expect(store.entries.map(\.content) == ["C", "A", "B"])
    }

    @Test func manyCopies_capAt20() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        for i in 0..<30 {
            pasteboard.set(string: "item\(i)")
            watcher.poll()
        }
        #expect(store.entries.count == 20)
        #expect(store.entries.first?.content == "item29")
    }

    @Test func changesBetweenPollsOnlyLatestIsSeen() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.set(string: "missed")
        pasteboard.set(string: "latest")
        watcher.poll()
        #expect(store.entries == [text("latest")])
    }

    // MARK: - タイマー

    @Test func startIsIdempotentAndStopStops() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        #expect(!watcher.isRunning)
        watcher.start(runLoop: .current)
        watcher.start(runLoop: .current)
        #expect(watcher.isRunning)
        watcher.stop()
        #expect(!watcher.isRunning)
    }

    @Test func timerPollsOnRunLoop() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        watcher.start(interval: 0.01, tolerance: 0, runLoop: .current)
        defer { watcher.stop() }
        pasteboard.set(string: "via timer")

        let deadline = Date().addingTimeInterval(5)
        while store.entries.isEmpty && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        #expect(store.entries == [text("via timer")])
    }
}
