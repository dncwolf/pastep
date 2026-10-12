import AppKit
import pastepCore

/// メニューバーアイコンと履歴メニュー。⌘⇧V でも同じメニューをカーソル位置に出す。
public final class MenuController: NSObject, NSMenuDelegate {
    public let menu = NSMenu()
    public var hotKeyRegistered = true

    private let statusItem: NSStatusItem
    private let builder = HistoryMenuBuilder()
    private let store: HistoryStore
    private let system: PasteSystem
    private let coordinator: PasteCoordinator
    /// メニューを開いた時点の最前面アプリ（ペースト先）
    private var pasteTarget: Int32?

    public init(store: HistoryStore, system: PasteSystem, coordinator: PasteCoordinator) {
        self.store = store
        self.system = system
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pastep")
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        builder.onSelect = { [weak self] entry in
            guard let self else { return }
            self.coordinator.paste(entry, into: self.pasteTarget)
        }
        builder.onOpenAccessibilitySettings = {
            MacPasteSystem.openAccessibilitySettings()
        }
    }

    /// アプリをアクティブにせずに表示するので、元のアプリのフォーカスはそのまま残る
    public func popUpAtCursor() {
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        pasteTarget = system.frontmostPID()
    }

    /// 開くときだけ中身を作る（コピーのたびに作り直さない）
    public func menuNeedsUpdate(_ menu: NSMenu) {
        builder.populate(
            menu,
            entries: store.entries,
            state: MenuState(canPaste: system.canPostKeystrokes, hotKeyRegistered: hotKeyRegistered)
        )
    }
}
