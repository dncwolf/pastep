import SwiftUI
import AppKit

public struct HistoryView: View {
    @ObservedObject public var store: HistoryStore
    public let onClose: () -> Void
    public let onSelect: (ClipboardEntry) -> Void

    public init(store: HistoryStore, onClose: @escaping () -> Void, onSelect: @escaping (ClipboardEntry) -> Void) {
        self.store = store
        self.onClose = onClose
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            if store.entries.isEmpty {
                Text("クリップボード履歴はありません")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.entries) { entry in
                            EntryRowView(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(entry)
                                }
                            Divider()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onExitCommand { onClose() }
    }
}

public struct EntryRowView: View {
    public let entry: ClipboardEntry

    public init(entry: ClipboardEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack {
            Text(entry.preview)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .help(entry.type == .filePath ? entry.content : entry.preview)
    }
}
