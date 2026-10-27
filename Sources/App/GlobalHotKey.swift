import Carbon
import Combine

/// 어느 앱에서든 ⌘⇧P로 타이머 시작/일시정지.
/// Carbon RegisterEventHotKey는 손쉬운 사용 권한 없이 동작함
final class GlobalHotKey {
    static let shared = GlobalHotKey()
    static let displayName = "⌘⇧P"

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?
    private var subscription: AnyCancellable?

    /// 설정의 globalHotKey 값을 따라 등록/해제
    func bind(to store: AppStore) {
        action = { [weak store] in store?.toggle() }
        subscription = store.$settings
            .map(\.globalHotKey)
            .removeDuplicates()
            .sink { [weak self] enabled in enabled ? self?.register() : self?.unregister() }
    }

    private func register() {
        guard hotKeyRef == nil else { return }
        if handlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hotKey.action?() }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        }
        let id = EventHotKeyID(signature: OSType(0x706F6D6F), id: 1) // 'pomo'
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(cmdKey | shiftKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }
}
