import AppKit
import Combine

class StatusBarController {
    private let store: HistoryStore
    private let statusItem: NSStatusItem
    private var historyPanel: HistoryPanel?
    private var cancellables = Set<AnyCancellable>()
    private(set) var shortcutActive: Bool = false

    init(store: HistoryStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pastep")
        }

        setupMenu()

        store.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshMenu() }
            .store(in: &cancellables)
    }

    private func setupMenu() {
        let menu = NSMenu()
        statusItem.menu = menu
        refreshMenu()
    }

    func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        // 履歴エントリ
        if store.entries.isEmpty {
            let item = NSMenuItem(title: "（履歴なし）", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for entry in store.entries {
                let item = NSMenuItem(
                    title: entry.preview,
                    action: #selector(entryClicked(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = entry
                if entry.type == .filePath {
                    item.toolTip = entry.content
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let showItem = NSMenuItem(
            title: "履歴を表示... (⌘⇧V)",
            action: #selector(showPanel),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let statusTitle = shortcutActive
            ? "ショートカット: 有効"
            : "ショートカット: 権限なし → クリックで設定を開く"
        let statusItem = NSMenuItem(
            title: statusTitle,
            action: shortcutActive ? nil : #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        statusItem.target = self
        statusItem.isEnabled = !shortcutActive
        menu.addItem(statusItem)

        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
    }

    func setShortcutActive(_ active: Bool) {
        shortcutActive = active
        refreshMenu()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func entryClicked(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? ClipboardEntry else { return }
        setToPasteboard(entry: entry)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            StatusBarController.performPaste()
        }
    }

    private static func performPaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    @objc private func showPanel() {
        togglePanel()
    }

    func togglePanel() {
        if historyPanel == nil {
            historyPanel = HistoryPanel(store: store)
        }
        let buttonFrame: NSRect
        if let button = statusItem.button, let window = button.window {
            let frameInWindow = button.convert(button.bounds, to: nil)
            buttonFrame = window.convertToScreen(frameInWindow)
        } else {
            buttonFrame = .zero
        }
        historyPanel?.toggle(relativeTo: buttonFrame)
    }

    private func setToPasteboard(entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if entry.type == .filePath {
            let url = URL(fileURLWithPath: entry.content)
            pasteboard.writeObjects([url as NSURL])
        } else {
            pasteboard.setString(entry.content, forType: .string)
        }
    }
}
