import Testing
import Foundation
@testable import pastepCore

final class MockPasteSystem: PasteSystem {
    enum Call: Equatable {
        case write(ClipboardEntry)
        case activate(Int32)
        case postPaste
    }

    var canPostKeystrokes = true
    var ownPID: Int32 = 100
    var frontmost: Int32? = 200
    private(set) var calls: [Call] = []

    func frontmostPID() -> Int32? { frontmost }
    func write(_ entry: ClipboardEntry) { calls.append(.write(entry)) }
    func activate(pid: Int32) { calls.append(.activate(pid)) }
    func postPasteKeystroke() { calls.append(.postPaste) }
}

@Suite struct PasteCoordinatorTests {
    let system = MockPasteSystem()
    let scheduler = ManualScheduler()
    var coordinator: PasteCoordinator {
        PasteCoordinator(system: system, scheduler: scheduler, pasteDelay: 0.05, activationDelay: 0.15)
    }

    @Test func targetStillFrontmost_writesThenPastesAfterShortDelay() {
        system.frontmost = 200
        #expect(coordinator.paste(text("hi"), into: 200) == .pasteScheduled)
        #expect(system.calls == [.write(text("hi"))])
        #expect(scheduler.delays == [0.05])

        scheduler.runAll()
        #expect(system.calls == [.write(text("hi")), .postPaste])
    }

    @Test func targetNotFrontmost_reactivatesBeforePasting() {
        system.frontmost = system.ownPID
        coordinator.paste(text("hi"), into: 200)
        #expect(system.calls == [.write(text("hi")), .activate(200)])
        #expect(scheduler.delays == [0.15])

        scheduler.runAll()
        #expect(system.calls == [.write(text("hi")), .activate(200), .postPaste])
    }

    @Test func unknownTarget_pastesWithoutActivating() {
        coordinator.paste(text("hi"), into: nil)
        scheduler.runAll()
        #expect(system.calls == [.write(text("hi")), .postPaste])
    }

    @Test func targetIsOwnProcess_neverActivatesItself() {
        system.frontmost = 300
        coordinator.paste(text("hi"), into: system.ownPID)
        scheduler.runAll()
        #expect(!system.calls.contains(.activate(system.ownPID)))
        #expect(system.calls.last == .postPaste)
    }

    @Test func withoutAccessibilityPermission_onlyCopies() {
        system.canPostKeystrokes = false
        system.frontmost = system.ownPID
        #expect(coordinator.paste(file("/tmp/a"), into: 200) == .copiedOnly)
        #expect(system.calls == [.write(file("/tmp/a"))])
        #expect(scheduler.pending.isEmpty)
    }

    @Test func keystrokeIsNotSentSynchronously() {
        // メニューが閉じきる前に ⌘V を送らないよう、必ず遅延させる
        coordinator.paste(text("hi"), into: 200)
        #expect(!system.calls.contains(.postPaste))
    }
}

@Suite struct MenuModelTests {
    @Test func emptyHistoryHasNoItems() {
        #expect(MenuModel.items(for: []).isEmpty)
    }

    @Test func firstTenEntriesGetNumberKeys() {
        let entries = (0..<12).map { text("e\($0)") }
        let keys = MenuModel.items(for: entries).map(\.keyEquivalent)
        #expect(keys == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "", ""])
    }

    @Test func itemsKeepOrderAndEntries() {
        let entries = [text("new"), file("/tmp/old.txt")]
        let items = MenuModel.items(for: entries)
        #expect(items.map(\.entry) == entries)
        #expect(items.map(\.title) == ["new", "old.txt"])
        #expect(items.map(\.toolTip) == ["new", "/tmp/old.txt"])
    }

    @Test func titleIsLimitedTo25Characters() {
        let items = MenuModel.items(for: [text(String(repeating: "x", count: 100))])
        #expect(items[0].title == String(repeating: "x", count: 25) + "…")
    }
}
