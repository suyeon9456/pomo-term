import SwiftUI

/// 터미널 테마 미니 타이머 (reference/TermMiniTimer.dc.html)
struct TerminalMiniTimer: View {
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
