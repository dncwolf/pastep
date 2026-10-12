import AppKit
import Testing
@testable import pastep

private func text(_ content: String) -> ClipboardEntry { ClipboardEntry(content: content, type: .text) }
private func file(_ path: String) -> ClipboardEntry { ClipboardEntry(content: path, type: .filePath) }
private func tempURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("pastep-tests-\(UUID().uuidString)/history.json")
}

@Test func title_flattensWhitespaceAndTruncates() {
    #expect(text("  a\n\n b\tc  ").title == "a b c")
    #expect(text(String(repeating: "あ", count: 30)).title == String(repeating: "あ", count: 25) + "…")
    #expect(text(" \n\t").title == "（空白のみ）")
    #expect(file("/tmp/dir/file.txt").title == "file.txt")
}

@Test func toolTip_truncatesLongTextOnly() {
    #expect(text("short").toolTip == "short")
    #expect(text(String(repeating: "x", count: 600)).toolTip == String(repeating: "x", count: 500) + "…")
    let path = "/" + String(repeating: "d", count: 600)
    #expect(file(path).toolTip == path)
}

@Test func add_movesDuplicateToFrontAndKeepsTwenty() {
    let history = History(fileURL: tempURL())
    for i in 0..<25 { history.add(text("\(i)")) }
    history.add(text("10"))
    #expect(history.entries.count == History.maxEntries)
    #expect(history.entries.prefix(3).map(\.content) == ["10", "24", "23"])
    #expect(history.entries.filter { $0.content == "10" }.count == 1)
}

@Test func add_ignoresEmptyAndOversizedText() {
    let history = History(fileURL: tempURL())
    history.add(text(""))
    history.add(text(String(repeating: "x", count: History.maxBytes + 1)))
    #expect(history.entries.isEmpty)
}

@Test func save_roundTripsWithOwnerOnlyPermissions() throws {
    let url = tempURL()
    let history = History(fileURL: url)
    history.add(text("a"))
    history.add(file("/tmp/f"))
    #expect(history.save())
    #expect(History(fileURL: url).entries == [file("/tmp/f"), text("a")])
    let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
    #expect(permissions == 0o600)
}

@Test func legacyDefaults_areMovedToFile() throws {
    let suite = "pastep.tests"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    // 旧形式（id・createdAt 付き）
    let legacy = #"[{"id":"D1CA997F-0000-0000-0000-000000000000","content":"old","type":"text","createdAt":813483127.2}]"#
    defaults.set(Data(legacy.utf8), forKey: History.legacyKey)

    let url = tempURL()
    #expect(History(fileURL: url, legacyDefaults: defaults).entries == [text("old")])
    #expect(defaults.data(forKey: History.legacyKey) == nil)
    #expect(History(fileURL: url).entries == [text("old")])
}

@MainActor @Test func pasteboard_prefersFileURLAndRoundTrips() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("pastep.tests.\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }

    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/a b.txt") as NSURL, "a b.txt" as NSString])
    #expect(pasteboard.readEntry() == file("/tmp/a b.txt"))

    pasteboard.write(text("hello\nworld"))
    #expect(pasteboard.readEntry() == text("hello\nworld"))
}

@MainActor @Test func menu_listsEntriesWithNumberKeys() {
    let history = History(fileURL: tempURL())
    for i in 0..<12 { history.add(text("\(i)")) }
    let controller = MenuController(history: history)
    controller.hotKeyRegistered = false
    controller.populate(canPaste: false)

    let titles = controller.menu.items.map(\.title)
    #expect(Array(titles.prefix(12)) == (0..<12).reversed().map { "\($0)" })
    #expect(controller.menu.items.prefix(12).map(\.keyEquivalent) == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "", ""])
    #expect(titles.contains { $0.contains("設定を開く") })
    #expect(titles.contains { $0.contains("登録できませんでした") })
    #expect(titles.last == "終了")
}
