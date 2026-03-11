import Foundation

enum EntryType: String, Codable {
    case text
    case filePath
}

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let type: EntryType
    let createdAt: Date

    init(content: String, type: EntryType) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.createdAt = Date()
    }

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.content == rhs.content && lhs.type == rhs.type
    }

    var preview: String {
        if type == .filePath {
            return URL(fileURLWithPath: content).lastPathComponent
        }
        return String(content.replacingOccurrences(of: "\n", with: " ").prefix(20))
    }
}
