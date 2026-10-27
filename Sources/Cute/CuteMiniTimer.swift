import SwiftUI

/// 귀여운 테마 미니 타이머 (reference/CuteMiniTimer.dc.html): 320×96 알약
struct CuteMiniTimer: View {
    @EnvironmentObject var store: AppStore
    var onOpenMain: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                CuteRing(progress: store.progress, mode: store.mode, diameter: 62, lineWidth: 7)
                TomatoMascot(mood: TomatoMood.of(mode: store.mode, running: store.isRunning), size: 44, lineScale: 2, simple: true)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.timeString)
                    .font(.system(size: 28))
                    .monospacedDigit()
                    .tracking(-0.3)
                    .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                Text(store.selectedTodo?.title ?? (store.mode == .focus ? "집중할 일을 골라주세요" : "\(store.mode.label) 시간"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cute.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: store.toggle) {
                if store.isRunning { CutePauseIcon(size: 20) } else { CutePlayIcon(size: 22).offset(x: 1) }
            }
            .buttonStyle(CuteCircleButtonStyle(fill: store.mode.cuteAccent, size: 48))
            .accessibilityLabel(store.isRunning ? "일시정지" : "시작")

            Button(action: onOpenMain) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("메인 창으로 펼치기")
        }
        .foregroundStyle(Color.cute.ink)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(width: 320, height: 96)
        .cuteSurface(Capsule(style: .circular), fill: .cute.window, shadow: 5)
        .contentShape(Capsule(style: .circular))
        .onTapGesture(count: 2, perform: onOpenMain)
        .contextMenu {
            Button("메인 창 열기", action: onOpenMain)
            Button("미니 타이머 닫기", action: onClose)
        }
        // 딱딱한 그림자가 잘리지 않도록 아래 여백
        .padding(.bottom, 5)
        .preferredColorScheme(.light)
    }
}
