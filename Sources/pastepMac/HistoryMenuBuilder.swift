import AppKit
import pastepCore

public struct MenuState: Equatable {
    public var canPaste: Bool
    public var hotKeyRegistered: Bool

    public init(canPaste: Bool, hotKeyRegistered: Bool) {
        self.canPaste = canPaste
        self.hotKeyRegistered = hotKeyRegistered
    }
}

/// 履歴メニューの中身を組み立てる。メニューを開く直前に毎回呼ばれる。
public final class HistoryMenuBuilder: NSObject {
    public static let emptyTitle = "（履歴なし）"
    public static let accessibilityTitle = "自動ペーストには権限が必要 → 設定を開く"
    public static let hotKeyFailedTitle = "⌘⇧V を登録できませんでした（他のアプリが使用中）"
    public static let quitTitle = "終了"

    public var onSelect: ((ClipboardEntry) -> Void)?
    public var onOpenAccessibilitySettings: (() -> Void)?

    public func populate(_ menu: NSMenu, entries: [ClipboardEntry], state: MenuState) {
        menu.autoenablesItems = false
        menu.removeAllItems()

        let items = MenuModel.items(for: entries)
        if items.isEmpty {
            menu.addItem(disabledItem(Self.emptyTitle))
        }
        for model in items {
            let item = NSMenuItem(title: model.title, action: #selector(entryClicked(_:)), keyEquivalent: model.keyEquivalent)
            item.keyEquivalentModifierMask = []
            item.target = self
            item.toolTip = model.toolTip
            item.representedObject = model.entry
            menu.addItem(item)
        }

        menu.addItem(.separator())

        if !state.canPaste {
            let item = NSMenuItem(title: Self.accessibilityTitle, action: #selector(openAccessibilitySettings(_:)), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        if !state.hotKeyRegistered {
            menu.addItem(disabledItem(Self.hotKeyFailedTitle))
        }

        let quit = NSMenuItem(title: Self.quitTitle, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command
        menu.addItem(quit)
    }

    @objc func entryClicked(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? ClipboardEntry else { return }
        onSelect?(entry)
    }

    @objc func openAccessibilitySettings(_ sender: NSMenuItem) {
        onOpenAccessibilitySettings?()
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
