import AppKit
import pastepCore
import pastepMac

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: HistoryStore!
    private var watcher: ClipboardWatcher!
    private var menuController: MenuController!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let persistence = FileHistoryPersistence(
            fileURL: FileHistoryPersistence.defaultFileURL(),
            legacyDefaults: .standard
        )
        store = HistoryStore(persistence: persistence)

        let pasteboard = SystemPasteboard()
        watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)

        let system = MacPasteSystem(pasteboard: pasteboard)
        menuController = MenuController(
            store: store,
            system: system,
            coordinator: PasteCoordinator(system: system)
        )

        let shortcut = HotKey.commandShiftV
        hotKey = HotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            // ホットキーのイベント処理中にメニューのトラッキングを始めないよう次のループで開く
            DispatchQueue.main.async { self?.menuController.popUpAtCursor() }
        }
        menuController.hotKeyRegistered = hotKey != nil

        watcher.start()
        MacPasteSystem.requestAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher.stop()
        store.flush()
    }
}
