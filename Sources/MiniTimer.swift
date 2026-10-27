import AppKit
import SwiftUI

/// 미니 타이머 뷰 (reference/TermMiniTimer.dc.html)
struct MiniTimerView: View {
    @EnvironmentObject var store: AppStore
    var onOpenMain: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        let accent = store.mode.accent
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(store.mode.upper)
                        .font(.term(11, .extraBold))
                        .foregroundStyle(Color.term.window)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 6)
                        .background(accent, in: RoundedRectangle(cornerRadius: 3))
                    Text(store.timeString)
                        .font(.term(30, .extraBold))
                        .tracking(-0.03 * 30)
                        .foregroundStyle(accent)
                        .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                    Text(store.cycleBar)
                        .font(.term(12))
                        .tracking(1)
                        .foregroundStyle(Color.term.error)
                }
                Text(store.asciiBar(width: 16))
                    .font(.term(12))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Text("→ \(store.selectedTodo?.title ?? "(none)")")
                    .font(.term(11))
                    .foregroundStyle(Color.term.dim)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: store.toggle) {
                Text(store.isRunning ? "❚❚" : "▶")
                    .font(.term(14, .extraBold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(accent))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isRunning ? "일시정지" : "시작")
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(width: 320, height: 92)
        .background(Color.term.window, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.term.borderStrong))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(count: 2, perform: onOpenMain)
        .contextMenu {
            Button("메인 창 열기", action: onOpenMain)
            Button("미니 타이머 닫기", action: onClose)
        }
        .preferredColorScheme(.dark)
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

        let view = MiniTimerView(
            onOpenMain: { store.openMainWindow?() },
            onClose: { [weak self] in self?.close() }
        )
        .environmentObject(store)
        panel.contentView = NSHostingView(rootView: view)

        // 처음엔 화면 오른쪽 위, 이후엔 마지막 위치 기억
        if !panel.setFrameUsingName("MiniTimer"), let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(CGPoint(x: screen.maxX - size.width - 20, y: screen.maxY - size.height - 20))
        }
        panel.setFrameAutosaveName("MiniTimer")
        return panel
    }
}
