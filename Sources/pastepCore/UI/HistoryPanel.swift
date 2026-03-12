import AppKit
import SwiftUI

public class HistoryPanel {
    private let panel: NSPanel
    private let store: HistoryStore
    private var previousApp: NSRunningApplication?
    private var outsideClickMonitor: Any?

    public init(store: HistoryStore) {
        self.store = store

        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true

        let hostingView = NSHostingView(
            rootView: HistoryView(
                store: store,
                onClose: { [weak self] in
                    self?.hide()
                },
                onSelect: { [weak self] entry in
                    self?.selectEntry(entry)
                }
            )
        )
        panel.contentView = hostingView
    }

    private func selectEntry(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if entry.type == .filePath {
            pasteboard.writeObjects([URL(fileURLWithPath: entry.content) as NSURL])
        } else {
            pasteboard.setString(entry.content, forType: .string)
        }
        let app = previousApp
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            app?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                performPaste()
            }
        }
    }

    public func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func hide() {
        panel.orderOut(nil)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        let width: CGFloat = 300
        let rowHeight: CGFloat = 36
        let count = max(store.entries.count, 1)
        let height = min(CGFloat(count) * rowHeight + 16, 440)

        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main

        var x = cursor.x - width / 2
        var y = cursor.y - height

        if let screen {
            x = min(x, screen.frame.maxX - width - 8)
            x = max(x, screen.frame.minX + 8)
            y = max(y, screen.frame.minY + 8)
        }

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }
}

public func performPaste() {
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
    down?.flags = .maskCommand
    let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
    up?.flags = .maskCommand
    down?.post(tap: .cgAnnotatedSessionEventTap)
    up?.post(tap: .cgAnnotatedSessionEventTap)
}
