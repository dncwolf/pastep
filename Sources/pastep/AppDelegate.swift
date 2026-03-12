import AppKit
import pastepCore

class AppDelegate: NSObject, NSApplicationDelegate {
    private var historyStore: HistoryStore!
    private var clipboardMonitor: ClipboardMonitor!
    private var statusBarController: StatusBarController!
    private var globalShortcutManager: GlobalShortcutManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        historyStore = HistoryStore()
        clipboardMonitor = ClipboardMonitor(store: historyStore)
        statusBarController = StatusBarController(store: historyStore)
        globalShortcutManager = GlobalShortcutManager { [weak self] in
            self?.statusBarController.togglePanel()
        }
        globalShortcutManager.onStatusChange = { [weak self] active in
            DispatchQueue.main.async {
                self?.statusBarController.setShortcutActive(active)
            }
        }

        clipboardMonitor.start()
        globalShortcutManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }
}
