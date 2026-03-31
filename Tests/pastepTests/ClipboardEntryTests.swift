import Testing
import Foundation
@testable import pastepCore

@Suite struct ClipboardEntryTests {

    @Test func preview_shortText() {
        let entry = ClipboardEntry(content: "Hello, World!", type: .text)
        #expect(entry.preview == "Hello, World!")
    }

    @Test func preview_longText() {
        let entry = ClipboardEntry(content: String(repeating: "a", count: 60), type: .text)
        #expect(entry.preview == String(repeating: "a", count: 50))
    }

    @Test func preview_multiline() {
        let entry = ClipboardEntry(content: "line1\nline2", type: .text)
        #expect(entry.preview == "line1 line2")
    }

    @Test func preview_filePath() {
        let entry = ClipboardEntry(content: "/Users/test/document.txt", type: .filePath)
        #expect(entry.preview == "document.txt")
    }

    @Test func preview_nestedPath() {
        let entry = ClipboardEntry(content: "/Users/sheep/projects/pastep/README.md", type: .filePath)
        #expect(entry.preview == "README.md")
    }

    @Test func equality_sameContentAndType() {
        let a = ClipboardEntry(content: "hello", type: .text)
        let b = ClipboardEntry(content: "hello", type: .text)
        #expect(a == b)
    }

    @Test func equality_differentContent() {
        let a = ClipboardEntry(content: "hello", type: .text)
        let b = ClipboardEntry(content: "world", type: .text)
        #expect(a != b)
    }

    @Test func equality_differentType() {
        let a = ClipboardEntry(content: "hello", type: .text)
        let b = ClipboardEntry(content: "hello", type: .filePath)
        #expect(a != b)
    }

    @Test func codable_roundTrip() throws {
        let original = ClipboardEntry(content: "test content", type: .text)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipboardEntry.self, from: data)
        #expect(decoded.content == original.content)
        #expect(decoded.type == original.type)
        #expect(decoded.id == original.id)
    }

    @Test func uniqueId() {
        let a = ClipboardEntry(content: "same", type: .text)
        let b = ClipboardEntry(content: "same", type: .text)
        #expect(a.id != b.id)
    }
}
