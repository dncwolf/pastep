import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    let onClose: () -> Void
    let onSelect: (ClipboardEntry) -> Void

    var body: some View {
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

struct EntryRowView: View {
    let entry: ClipboardEntry

    var body: some View {
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
