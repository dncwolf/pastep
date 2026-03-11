import AppKit
import Carbon

class GlobalShortcutManager {
    private let action: () -> Void
    var onStatusChange: ((Bool) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func start() {
        if AXIsProcessTrusted() {
            registerTap()
        } else {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            )
            print("[pastep] アクセシビリティ権限を要求しました。")
            onStatusChange?(false)
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                if AXIsProcessTrusted() {
                    self?.pollTimer?.invalidate()
                    self?.pollTimer = nil
                    self?.registerTap()
                }
            }
        }
    }

    private func registerTap() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<GlobalShortcutManager>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                return manager.handle(event: event)
            },
            userInfo: selfPtr
        )

        guard let tap else {
            print("[pastep] CGEvent tap の作成に失敗しました。")
            Unmanaged<GlobalShortcutManager>.fromOpaque(selfPtr).release()
            onStatusChange?(false)
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[pastep] ショートカット (⌘⇧V) 登録完了")
        onStatusChange?(true)
    }

    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        // keyCode 9 = 'v', flags: Cmd + Shift のみ
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let required: CGEventFlags = [.maskCommand, .maskShift]

        if keyCode == 9 && flags.intersection([.maskControl, .maskShift, .maskCommand, .maskAlternate]) == required {
            print("[pastep] ⌘⇧V 検知")
            DispatchQueue.main.async { [weak self] in
                self?.action()
            }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    deinit {
        pollTimer?.invalidate()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}
