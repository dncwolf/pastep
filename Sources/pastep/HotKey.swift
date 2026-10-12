import Carbon

private var hotKeyAction: (() -> Void)?

/// ⌘⇧V をグローバルショートカットとして登録する。他アプリが使用中などで失敗したら false。
/// Carbon の RegisterEventHotKey は登録したキーが押されたときだけ呼ばれ、アクセシビリティ権限も不要で、キーは他アプリに渡らない。
func registerCommandShiftV(_ action: @escaping () -> Void) -> Bool {
    var ref: EventHotKeyRef?
    let id = EventHotKeyID(signature: 0x5053_5450, id: 1) // 'PSTP'
    guard RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), id, GetApplicationEventTarget(), 0, &ref) == noErr else {
        return false
    }
    hotKeyAction = action
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    // ponytail: 登録するホットキーは1つだけなので、届いたイベントの ID は確かめない
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        hotKeyAction?()
        return noErr
    }, 1, &spec, nil, nil)
    return true
}
