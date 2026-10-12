import AppKit
import pastepCore

public final class MacPasteSystem: PasteSystem {
    private let pasteboard: SystemPasteboard

    public init(pasteboard: SystemPasteboard = SystemPasteboard()) {
        self.pasteboard = pasteboard
    }

    public var canPostKeystrokes: Bool { AXIsProcessTrusted() }

    public var ownPID: Int32 { ProcessInfo.processInfo.processIdentifier }

    public func frontmostPID() -> Int32? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    public func write(_ entry: ClipboardEntry) {
        pasteboard.write(entry)
    }

    public func activate(pid: Int32) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        if #available(macOS 14, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }

    public func postPasteKeystroke() {
        for event in Self.makePasteEvents() {
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    /// ⌘V の keyDown / keyUp
    static func makePasteEvents() -> [CGEvent] {
        let source = CGEventSource(stateID: .hidSystemState)
        return [true, false].compactMap { keyDown in
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyCode.v), keyDown: keyDown)
            event?.flags = .maskCommand
            return event
        }
    }

    /// アクセシビリティ権限がなければシステムの許可ダイアログを出す
    public static func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

enum KeyCode {
    /// kVK_ANSI_V
    static let v: UInt16 = 0x09
}
