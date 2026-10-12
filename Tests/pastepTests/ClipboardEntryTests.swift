import Testing
import Foundation
@testable import pastepCore

@Suite struct ClipboardEntryTests {

    // MARK: - title

    @Test func title_shortTextUnchanged() {
        #expect(text("Hello, World!").title(maxLength: 25) == "Hello, World!")
    }

    @Test func title_exactlyMaxLengthIsNotTruncated() {
        let content = String(repeating: "a", count: 25)
        #expect(text(content).title(maxLength: 25) == content)
    }

    @Test func title_longTextTruncatedWithEllipsis() {
        let content = String(repeating: "a", count: 26)
        #expect(text(content).title(maxLength: 25) == String(repeating: "a", count: 25) + "…")
    }

    @Test(arguments: [
        ("line1\nline2", "line1 line2"),
        ("line1\r\nline2", "line1 line2"),
        ("a\tb", "a b"),
        ("a   \n\n  b", "a b"),
        ("  \n indented", "indented"),
        ("trailing \n ", "trailing"),
    ])
    func title_whitespaceIsCollapsedAndTrimmed(input: String, expected: String) {
        #expect(text(input).title(maxLength: 25) == expected)
    }

    @Test func title_whitespaceOnlyTextHasPlaceholder() {
        #expect(text(" \n\t ").title(maxLength: 25) == ClipboardEntry.whitespaceOnlyTitle)
    }

    @Test func title_countsGraphemesNotScalars() {
        // 👨‍👩‍👧 は複数のスカラーからなる1文字、が は結合文字を含む1文字
        let content = "👨‍👩‍👧が" + String(repeating: "x", count: 30)
        let title = text(content).title(maxLength: 3)
        #expect(title == "👨‍👩‍👧がx…")
    }

    @Test func title_japaneseText() {
        #expect(text("こんにちは\n世界").title(maxLength: 25) == "こんにちは 世界")
    }

    @Test(arguments: [3, 4])
    func title_spaceAtCutPointIsNotIncluded(maxLength: Int) {
        #expect(text("abc def").title(maxLength: maxLength) == "abc…")
    }

    @Test func title_hugeTextIsCheap() {
        // 走査は先頭だけなので数MBでも即座に終わる
        let content = String(repeating: "word ", count: 1_000_000)
        #expect(text(content).title(maxLength: 25) == "word word word word word…")
    }

    @Test(arguments: [
        ("/Users/test/document.txt", "document.txt"),
        ("/Users/sheep/projects/pastep/README.md", "README.md"),
        ("/Users/test/folder/", "folder"),
        ("/", "/"),
    ])
    func title_filePathShowsFileName(path: String, expected: String) {
        #expect(file(path).title(maxLength: 25) == expected)
    }

    @Test func title_longFileNameIsNotTruncated() {
        let name = String(repeating: "n", count: 40) + ".txt"
        #expect(file("/tmp/" + name).title(maxLength: 25) == name)
    }

    // MARK: - toolTip

    @Test func toolTip_filePathIsFullPath() {
        #expect(file("/Users/test/document.txt").toolTip(maxLength: 10) == "/Users/test/document.txt")
    }

    @Test func toolTip_textKeepsNewlines() {
        #expect(text("a\nb").toolTip(maxLength: 10) == "a\nb")
    }

    @Test func toolTip_longTextIsCapped() {
        let content = String(repeating: "z", count: 600)
        #expect(text(content).toolTip(maxLength: 500) == String(repeating: "z", count: 500) + "…")
    }

    // MARK: - equality

    @Test func equality_ignoresIdAndDate() {
        let a = ClipboardEntry(content: "hello", type: .text, id: UUID(), createdAt: Date(timeIntervalSince1970: 0))
        let b = ClipboardEntry(content: "hello", type: .text, id: UUID(), createdAt: Date())
        #expect(a == b)
    }

    @Test func equality_differentContent() {
        #expect(text("hello") != text("world"))
    }

    @Test func equality_differentType() {
        #expect(text("/tmp/a") != file("/tmp/a"))
    }

    @Test func newEntriesHaveUniqueIds() {
        #expect(text("same").id != text("same").id)
    }

    // MARK: - Codable

    @Test func codable_roundTripKeepsAllFields() throws {
        let original = ClipboardEntry(content: "test\ncontent", type: .filePath)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardEntry.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.content == original.content)
        #expect(decoded.type == original.type)
        #expect(decoded.createdAt == original.createdAt)
    }

    @Test func codable_decodesFormatWrittenByPreviousVersion() throws {
        // 旧バージョン（UserDefaults 保存）と同じ JSONEncoder 既定形式
        let json = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","content":"old","type":"text","createdAt":700000000},
         {"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","content":"/tmp/x","type":"filePath","createdAt":700000001.5}]
        """
        let decoded = try JSONDecoder().decode([ClipboardEntry].self, from: Data(json.utf8))
        #expect(decoded.count == 2)
        #expect(decoded[0].content == "old")
        #expect(decoded[0].type == .text)
        #expect(decoded[0].createdAt == Date(timeIntervalSinceReferenceDate: 700000000))
        #expect(decoded[1].type == .filePath)
    }

    @Test func codable_unknownTypeFailsToDecode() {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","content":"x","type":"image","createdAt":0}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ClipboardEntry.self, from: Data(json.utf8))
        }
    }
}
