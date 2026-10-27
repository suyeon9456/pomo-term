import AppKit
import SwiftUI

/// 패널은 SwiftUI 씬 밖이라 테마를 직접 읽어서 넣어줌
private struct MiniTimerHost: View {
    @AppStorage(ThemeID.storageKey) private var themeID: ThemeID = .terminal
    var onOpenMain: () -> Void
    var onClose: () -> Void

    var body: some View {
        MiniTimerView(onOpenMain: onOpenMain, onClose: onClose)
            .environment(\.themeID, themeID)
    }
}

/// borderless 패널은 기본적으로 key가 될 수 없어 버튼·우클릭이 막히므로 허용 (nonactivating이라 앱 포커스는 안 뺏음)
private final class MiniPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// 항상 위에 떠 있는 미니 타이머 창. 다른 앱을 쓰는 중에도 포커스를 뺏지 않음
final class MiniTimerController {
    static let shared = MiniTimerController()

    private var panel: NSPanel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(store: AppStore) {
        if isVisible { close() } else { show(store: store) }
    }

    func show(store: AppStore) {
        if panel == nil { panel = makePanel(store: store) }
        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel(store: AppStore) -> NSPanel {
        let size = CGSize(width: 320, height: 92)
        let panel = MiniPanel(contentRect: CGRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let view = MiniTimerHost(
            onOpenMain: { store.openMainWindow?() },
            onClose: { [weak self] in self?.close() }
        )
        .environmentObject(store)
        // 테마마다 크기가 달라서 내용 크기에 맞춰 패널 크기를 바꿈
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        panel.contentViewController = controller

        // 처음엔 화면 오른쪽 위, 이후엔 마지막 위치 기억
        if !panel.setFrameUsingName("MiniTimer"), let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(CGPoint(x: screen.maxX - size.width - 20, y: screen.maxY - size.height - 20))
        }
        panel.setFrameAutosaveName("MiniTimer")
        return panel
    }
}
