import Foundation

public enum EntryType: String, Codable {
    case text
    case filePath
}

public struct ClipboardEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let content: String
    public let type: EntryType
    public let createdAt: Date

    public init(content: String, type: EntryType) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.createdAt = Date()
    }

    public static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.content == rhs.content && lhs.type == rhs.type
    }

    public var preview: String {
        if type == .filePath {
            return URL(fileURLWithPath: content).lastPathComponent
        }
        return String(content.replacingOccurrences(of: "\n", with: " ").prefix(20))
    }
}
