import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let history = History(legacyDefaults: .standard)
    private lazy var menuController = MenuController(history: history)
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pastep")
        statusItem.menu = menuController.menu
        self.statusItem = statusItem

        menuController.hotKeyRegistered = registerCommandShiftV { [weak self] in
            // ホットキーのイベント処理中にメニューのトラッキングを始めないよう次のループで開く
            DispatchQueue.main.async { self?.menuController.popUpAtCursor() }
        }

        watchPasteboard()
        // 自動ペースト用のアクセシビリティ権限がなければシステムの許可ダイアログを出す
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    func applicationWillTerminate(_ notification: Notification) {
        history.save()
    }

    /// macOS にはペーストボードの変更通知がないので changeCount をポーリングする。
    /// 変化がなければ内容は読まない。起動時にあった内容は履歴に入れない。
    private func watchPasteboard() {
        let pasteboard = NSPasteboard.general
        var lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.5, repeats: true) { [history] _ in
            guard pasteboard.changeCount != lastChangeCount else { return }
            lastChangeCount = pasteboard.changeCount
            if let entry = pasteboard.readEntry() { history.add(entry) }
        }
        timer.tolerance = 0.25 // OS がタイマー起動をまとめられるようにする（省電力）
        // .common: メニュー表示中（イベントトラッキング中）も監視を続ける
        RunLoop.main.add(timer, forMode: .common)
    }
}
