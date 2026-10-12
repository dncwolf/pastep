import Testing
import AppKit
import Carbon
@testable import pastepCore
@testable import pastepMac

/// 実際の NSPasteboard を使うが、システムのクリップボードではなく専用の名前付きペーストボードを使う
private func withPrivatePasteboard(_ body: (NSPasteboard) throws -> Void) rethrows {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("pastep.tests.\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    try body(pasteboard)
}

// AppKit / Carbon はメインスレッドで使う
@MainActor @Suite struct SystemPasteboardTests {

    @Test func writeText_readsBackAsString() {
        withPrivatePasteboard { pb in
            let adapter = SystemPasteboard(pb)
            adapter.write(text("hello\nworld"))
            #expect(adapter.readString() == "hello\nworld")
            #expect(adapter.readFileURLs().isEmpty)
        }
    }

    @Test func writeFile_readsBackAsFileURL() {
        withPrivatePasteboard { pb in
            let adapter = SystemPasteboard(pb)
            adapter.write(file("/tmp/pastep test.txt"))
            #expect(adapter.readFileURLs().map(\.path) == ["/tmp/pastep test.txt"])
        }
    }

    @Test func webURL_isNotTreatedAsFile() {
        withPrivatePasteboard { pb in
            pb.clearContents()
            pb.writeObjects([NSURL(string: "https://example.com/a")!])
            #expect(SystemPasteboard(pb).readFileURLs().isEmpty)
        }
    }

    @Test func multipleFiles_allReturnedInOrder() {
        withPrivatePasteboard { pb in
            pb.clearContents()
            pb.writeObjects([URL(fileURLWithPath: "/tmp/a") as NSURL, URL(fileURLWithPath: "/tmp/b") as NSURL])
            #expect(SystemPasteboard(pb).readFileURLs().map(\.path) == ["/tmp/a", "/tmp/b"])
        }
    }

    @Test func write_replacesPreviousContentAndBumpsChangeCount() {
        withPrivatePasteboard { pb in
            let adapter = SystemPasteboard(pb)
            adapter.write(file("/tmp/a"))
            let before = adapter.changeCount
            adapter.write(text("now text"))
            #expect(adapter.changeCount != before)
            #expect(adapter.readFileURLs().isEmpty)
            #expect(adapter.readString() == "now text")
        }
    }

    // MARK: - 実ペーストボード + 監視 + 履歴の結合

    @Test func watcherRecordsRealCopies() {
        withPrivatePasteboard { pb in
            let store = makeStore()
            let watcher = ClipboardWatcher(pasteboard: SystemPasteboard(pb), store: store)

            pb.clearContents()
            pb.setString("copied text", forType: .string)
            watcher.poll()

            // Finder と同様にファイル URL とファイル名文字列を両方載せる
            pb.clearContents()
            pb.writeObjects([URL(fileURLWithPath: "/tmp/doc.pdf") as NSURL])
            pb.setString("doc.pdf", forType: .string)
            watcher.poll()

            pb.clearContents()
            pb.writeObjects([NSURL(string: "https://example.com")!])
            pb.setString("https://example.com", forType: .string)
            watcher.poll()

            #expect(store.entries == [text("https://example.com"), file("/tmp/doc.pdf"), text("copied text")])
        }
    }

    @Test func selectingAnEntryRoundTripsThroughThePasteboard() {
        withPrivatePasteboard { pb in
            let store = makeStore()
            let adapter = SystemPasteboard(pb)
            let watcher = ClipboardWatcher(pasteboard: adapter, store: store)
            for content in ["one", "two", "three"] {
                adapter.write(text(content))
                watcher.poll()
            }

            // 履歴から "one" を選ぶ → ペーストボードに書かれ、次の監視で先頭に来る
            let system = MacPasteSystem(pasteboard: adapter)
            system.write(text("one"))
            watcher.poll()
            #expect(adapter.readString() == "one")
            #expect(store.entries.map(\.content) == ["one", "three", "two"])
        }
    }

    @Test func imageOnlyContentIsIgnored() {
        withPrivatePasteboard { pb in
            let store = makeStore()
            let watcher = ClipboardWatcher(pasteboard: SystemPasteboard(pb), store: store)
            pb.clearContents()
            pb.setData(Data([0x89, 0x50, 0x4E, 0x47]), forType: .png)
            #expect(watcher.poll() == false)
            #expect(store.entries.isEmpty)
        }
    }
}

@MainActor @Suite struct HistoryMenuBuilderTests {
    let builder = HistoryMenuBuilder()
    let menu = NSMenu()
    let allowed = MenuState(canPaste: true, hotKeyRegistered: true)

    private func titles() -> [String] {
        menu.items.map { $0.isSeparatorItem ? "---" : $0.title }
    }

    @Test func emptyHistory_showsDisabledPlaceholderAndQuit() {
        builder.populate(menu, entries: [], state: allowed)
        #expect(titles() == [HistoryMenuBuilder.emptyTitle, "---", HistoryMenuBuilder.quitTitle])
        #expect(menu.items[0].isEnabled == false)
    }

    @Test func entries_areListedNewestFirstWithShortcuts() {
        builder.populate(menu, entries: [text("new\nline"), file("/tmp/old.txt")], state: allowed)
        #expect(titles() == ["new line", "old.txt", "---", HistoryMenuBuilder.quitTitle])

        let first = menu.items[0]
        #expect(first.keyEquivalent == "1")
        #expect(first.keyEquivalentModifierMask.isEmpty)
        #expect(first.toolTip == "new\nline")
        #expect(first.isEnabled)
        #expect(menu.items[1].keyEquivalent == "2")
        #expect(menu.items[1].toolTip == "/tmp/old.txt")
    }

    @Test func clickingAnEntry_callsOnSelectWithThatEntry() throws {
        var selected: [ClipboardEntry] = []
        builder.onSelect = { selected.append($0) }
        builder.populate(menu, entries: [text("a"), file("/tmp/b")], state: allowed)

        let item = menu.items[1]
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        target.perform(action, with: item)

        #expect(selected == [file("/tmp/b")])
    }

    @Test func missingPermission_showsSettingsItemThatWorks() throws {
        var opened = 0
        builder.onOpenAccessibilitySettings = { opened += 1 }
        builder.populate(menu, entries: [], state: MenuState(canPaste: false, hotKeyRegistered: true))

        let item = try #require(menu.items.first { $0.title == HistoryMenuBuilder.accessibilityTitle })
        #expect(item.isEnabled)
        (item.target as? NSObject)?.perform(item.action!, with: item)
        #expect(opened == 1)
    }

    @Test func permissionGranted_hidesSettingsItem() {
        builder.populate(menu, entries: [], state: allowed)
        #expect(!titles().contains(HistoryMenuBuilder.accessibilityTitle))
    }

    @Test func hotKeyFailure_isShown() {
        builder.populate(menu, entries: [], state: MenuState(canPaste: true, hotKeyRegistered: false))
        let item = menu.items.first { $0.title == HistoryMenuBuilder.hotKeyFailedTitle }
        #expect(item?.isEnabled == false)
    }

    @Test func repopulating_replacesItemsInsteadOfAppending() {
        builder.populate(menu, entries: [text("a"), text("b")], state: allowed)
        builder.populate(menu, entries: [text("c")], state: allowed)
        #expect(titles() == ["c", "---", HistoryMenuBuilder.quitTitle])
    }

    @Test func quitItem_terminatesApp() {
        builder.populate(menu, entries: [], state: allowed)
        let quit = menu.items.last
        #expect(quit?.action == #selector(NSApplication.terminate(_:)))
        #expect(quit?.keyEquivalent == "q")
        #expect(quit?.keyEquivalentModifierMask == .command)
    }

    @Test func fullHistory_listsAllTwentyEntries() {
        let entries = (0..<20).map { text("entry \($0)") }
        builder.populate(menu, entries: entries, state: allowed)
        let entryItems = menu.items.filter { $0.representedObject is ClipboardEntry }
        #expect(entryItems.count == 20)
        #expect(entryItems[9].keyEquivalent == "0")
        #expect(entryItems[10].keyEquivalent == "")
    }
}

@MainActor @Suite struct MacPasteSystemTests {
    @Test func pasteEvents_areCommandVDownThenUp() throws {
        let events = MacPasteSystem.makePasteEvents()
        try #require(events.count == 2)
        #expect(events.map(\.type) == [.keyDown, .keyUp])
        for event in events {
            #expect(event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_ANSI_V))
            #expect(event.flags.contains(.maskCommand))
            #expect(!event.flags.contains(.maskShift))
        }
    }

    @Test func ownPID_isThisProcess() {
        #expect(MacPasteSystem().ownPID == ProcessInfo.processInfo.processIdentifier)
    }
}

@MainActor @Suite(.serialized) struct HotKeyTests {
    // 他で使われていなさそうな組み合わせ（⌃⌥⇧⌘ F19）
    let keyCode = UInt32(kVK_F19)
    let modifiers = UInt32(cmdKey | shiftKey | optionKey | controlKey)

    @Test func commandShiftV_constants() {
        #expect(HotKey.commandShiftV.keyCode == UInt32(kVK_ANSI_V))
        #expect(HotKey.commandShiftV.modifiers == UInt32(cmdKey | shiftKey))
    }

    @Test func handle_onlyRespondsToOwnID() throws {
        var fired = 0
        let hotKey = try #require(HotKey(keyCode: keyCode, modifiers: modifiers) { fired += 1 })

        #expect(hotKey.handle(EventHotKeyID(signature: HotKey.signature, id: hotKey.id)))
        #expect(!hotKey.handle(EventHotKeyID(signature: HotKey.signature, id: hotKey.id + 1)))
        #expect(!hotKey.handle(EventHotKeyID(signature: 0x1234_5678, id: hotKey.id)))
        #expect(fired == 1)
    }

    @Test func eachHotKeyGetsADistinctID() throws {
        let a = try #require(HotKey(keyCode: keyCode, modifiers: modifiers) {})
        let b = try #require(HotKey(keyCode: UInt32(kVK_F18), modifiers: modifiers) {})
        #expect(a.id != b.id)
    }

    @Test func releasingUnregistersSoItCanBeRegisteredAgain() throws {
        for _ in 0..<3 {
            let hotKey = HotKey(keyCode: keyCode, modifiers: modifiers) {}
            #expect(hotKey != nil)
        }
    }
}
