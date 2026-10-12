import AppKit
import Carbon

/// 履歴メニュー。メニューバーアイコンと ⌘⇧V（カーソル位置）で同じメニューを出す。
final class MenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    var hotKeyRegistered = true

    private let history: History
    /// メニューを開いた時点の最前面アプリ（ペースト先）
    private var pasteTarget: NSRunningApplication?

    init(history: History) {
        self.history = history
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    /// アプリをアクティブにせずに出すので、元のアプリのフォーカスはそのまま残る
    func popUpAtCursor() {
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        pasteTarget = NSWorkspace.shared.frontmostApplication
    }

    /// 開くときだけ中身を作る（コピーのたびに作り直さない）
    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(canPaste: AXIsProcessTrusted())
    }

    func populate(canPaste: Bool) {
        menu.removeAllItems()
        if history.entries.isEmpty { menu.addItem(disabledItem("（履歴なし）")) }
        for (index, entry) in history.entries.enumerated() {
            // 先頭10件に 1〜9, 0 を割り当て、メニュー表示中に押すと即選択
            let key = index < 10 ? String((index + 1) % 10) : ""
            let item = NSMenuItem(title: entry.title, action: #selector(select(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = []
            item.target = self
            item.toolTip = entry.toolTip
            item.representedObject = entry
            menu.addItem(item)
        }
        menu.addItem(.separator())

        if !canPaste {
            let item = NSMenuItem(title: "自動ペーストには権限が必要 → 設定を開く", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        if !hotKeyRegistered { menu.addItem(disabledItem("⌘⇧V を登録できませんでした（他のアプリが使用中）")) }
        menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// クリップボードにセットし、アクセシビリティ権限があれば元のアプリへ ⌘V を送る
    @objc private func select(_ item: NSMenuItem) {
        guard let entry = item.representedObject as? ClipboardEntry else { return }
        NSPasteboard.general.write(entry)
        guard AXIsProcessTrusted() else { return }

        var delay = 0.05
        if let target = pasteTarget,
           target.processIdentifier != NSRunningApplication.current.processIdentifier,
           target.processIdentifier != NSWorkspace.shared.frontmostApplication?.processIdentifier {
            if #available(macOS 14, *) { target.activate() } else { target.activate(options: .activateIgnoringOtherApps) }
            delay = 0.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let source = CGEventSource(stateID: .hidSystemState)
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: keyDown)
                event?.flags = .maskCommand
                event?.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
