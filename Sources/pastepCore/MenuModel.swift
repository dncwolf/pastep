import Foundation

/// メニューに並べる1行ぶんの表示内容
public struct MenuEntryItem: Equatable {
    public let entry: ClipboardEntry
    public let title: String
    public let toolTip: String
    /// 先頭10件に 1〜9, 0 を割り当てる（メニュー表示中に数字キーで即選択）
    public let keyEquivalent: String
}

public enum MenuModel {
    public static let titleLength = 25
    public static let toolTipLength = 500
    static let shortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    public static func items(for entries: [ClipboardEntry]) -> [MenuEntryItem] {
        entries.enumerated().map { index, entry in
            MenuEntryItem(
                entry: entry,
                title: entry.title(maxLength: titleLength),
                toolTip: entry.toolTip(maxLength: toolTipLength),
                keyEquivalent: index < shortcutKeys.count ? shortcutKeys[index] : ""
            )
        }
    }
}
