import Carbon

/// Carbon の RegisterEventHotKey によるグローバルショートカット。
/// CGEvent tap と違い、全キー入力を監視せず、登録したキーが押されたときだけ呼ばれる。
/// アクセシビリティ権限も不要で、キーは他アプリに渡らない。
public final class HotKey {
    static let signature: OSType = 0x5053_5450 // 'PSTP'
    private static var nextID: UInt32 = 1

    public static let commandShiftV = (keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))

    let id: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// 登録に失敗した場合（他アプリが同じキーを使っている等）は nil
    public init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.id = HotKey.nextID
        HotKey.nextID += 1
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // deinit でハンドラを外すので unretained で安全
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                return hotKey.handle(hotKeyID) ? noErr : OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: HotKey.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr, hotKeyRef != nil else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            handlerRef = nil
            return nil
        }
    }

    /// 自分宛てのイベントなら action を呼んで true
    func handle(_ hotKeyID: EventHotKeyID) -> Bool {
        guard hotKeyID.signature == HotKey.signature, hotKeyID.id == id else { return false }
        action()
        return true
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
