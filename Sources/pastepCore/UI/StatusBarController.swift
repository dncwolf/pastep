import AppKit
import Combine

public class StatusBarController {
    private let store: HistoryStore
    private let statusItem: NSStatusItem
    private var historyPanel: HistoryPanel?
    private var cancellables = Set<AnyCancellable>()
    public private(set) var shortcutActive: Bool = false

    public init(store: HistoryStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pastep")
        }

        let menu = NSMenu()
        statusItem.menu = menu
        refreshMenu()

        store.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshMenu() }
            .store(in: &cancellables)
    }

    public func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        // 履歴エントリ
        if store.entries.isEmpty {
            let item = NSMenuItem(title: "（履歴なし）", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for entry in store.entries {
                let menuTitle: String
                if entry.type == .filePath {
                    menuTitle = entry.preview
                } else {
                    menuTitle = String(entry.content.replacingOccurrences(of: "\n", with: " ").prefix(25))
                }
                let item = NSMenuItem(
                    title: menuTitle,
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
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let accessibilityTitle = shortcutActive
            ? "アクセシビリティ権限: 許可済み"
            : "アクセシビリティ権限: 未許可 → クリックで設定を開く"
        let accessibilityItem = NSMenuItem(
            title: accessibilityTitle,
            action: shortcutActive ? nil : #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.isEnabled = !shortcutActive
        menu.addItem(accessibilityItem)

        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
    }

    public func setShortcutActive(_ active: Bool) {
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
            performPaste()
        }
    }

    @objc public func togglePanel() {
        if historyPanel == nil {
            historyPanel = HistoryPanel(store: store)
        }
        historyPanel?.toggle()
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
