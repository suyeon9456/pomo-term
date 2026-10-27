import SwiftUI

/// 귀여운 테마 타이머 패널: 모드 탭 · 말풍선 · 링 + 캐릭터 · 시간 · 컨트롤 · 지금 키우는 토마토
struct CuteTimerPanel: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 18) {
            modeTabs

            SpeechBubble(text: bubbleText)
                .padding(.top, 6)

            ZStack {
                CuteRing(progress: store.progress, mode: store.mode, diameter: 232, lineWidth: 16, outlined: true)
                BobbingMascot(mood: TomatoMood.of(mode: store.mode, running: store.isRunning), size: 170)
            }
            .frame(width: 260, height: 260)

            VStack(spacing: 6) {
                Text(store.timeString)
                    .font(.system(size: 66, weight: .light))
                    .monospacedDigit()
                    .tracking(-1.3)
                    .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                Text(store.mode == .focus ? "\(store.cycleLength)번 중 \(store.session)번째 토마토" : "\(store.mode.label) 시간")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cute.inkSecondary)
                minuteAdjuster
            }

            controls

            currentTaskCard
                .padding(.top, 4)

            Text(nextText)
                .font(.system(size: 12))
                .foregroundStyle(Color.cute.inkSecondary)
                .padding(.top, -8)

            Spacer(minLength: 0)
        }
        .padding(.top, 26)
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(store.mode.cutePanel)
        .overlay(alignment: .leading) { Rectangle().fill(Color.cute.sidebarDivider).frame(width: 2) }
        .animation(.easeInOut(duration: 0.25), value: store.mode)
    }

    private var modeTabs: some View {
        HStack(spacing: 4) {
            ForEach(TimerMode.allCases, id: \.self) { m in
                let selected = m == store.mode
                Button { store.switchMode(m) } label: {
                    Text(m.label)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selected ? m.cuteTab : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .circular))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .cuteSurface(radius: 16, fill: .white)
    }

    /// 쉿, 집중 중이야… N분만 더! (N = 남은 시간을 분으로 올림)
    private var bubbleText: String {
        let leftMin = (store.remaining + 59) / 60
        switch (store.mode == .focus, store.isRunning) {
        case (true, false): return "준비됐어? 같이 시작하자!"
        case (true, true): return "쉿, 집중 중이야… \(leftMin)분만 더!"
        case (false, false): return "수고했어! 잠깐 쉬어갈까?"
        case (false, true): return "물 한 잔 마시고 기지개 쭉~"
        }
    }

    /// − 25분 + (실행 중엔 비활성)
    private var minuteAdjuster: some View {
        let step = AppStore.minuteStep(for: store.mode)
        return HStack(spacing: 0) {
            Button { store.adjustCurrentMinutes(by: -1) } label: {
                Image(systemName: "minus").font(.system(size: 11, weight: .heavy)).frame(width: 30, height: 26).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(store.mode.label) \(step)분 줄이기")
            Text("\(store.minutesSetting(for: store.mode))분")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 40)
            Button { store.adjustCurrentMinutes(by: 1) } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .heavy)).frame(width: 30, height: 26).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(store.mode.label) \(step)분 늘리기")
        }
        .cuteSurface(Capsule(style: .circular), fill: .white, border: .cute.rowBorder)
        .opacity(store.isRunning ? 0.45 : 1)
        .disabled(store.isRunning)
    }

    private var controls: some View {
        HStack(spacing: 22) {
            Button(action: store.reset) {
                Image(systemName: "arrow.counterclockwise").font(.system(size: 20, weight: .bold))
            }
            .buttonStyle(CuteCircleButtonStyle(size: 50))
            .accessibilityLabel("타이머 초기화")

            Button(action: store.toggle) {
                if store.isRunning { CutePauseIcon(size: 28) } else { CutePlayIcon(size: 32).offset(x: 2) }
            }
            .buttonStyle(CuteCircleButtonStyle(fill: store.mode.cuteAccent, size: 78, shadow: 5, lineWidth: 2.5))
            .accessibilityLabel(store.isRunning ? "일시정지" : "시작")

            Button(action: store.skip) {
                Image(systemName: "forward.end").font(.system(size: 19, weight: .bold))
            }
            .buttonStyle(CuteCircleButtonStyle(size: 50))
            .accessibilityLabel("다음 단계로 건너뛰기")
        }
    }

    private var currentTaskCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("지금 키우는 토마토").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.cute.inkSecondary)
                Text(store.selectedTodo.map { t in (store.parent(of: t).map { "\($0.title) › " } ?? "") + t.title }
                     ?? "목록에서 집중할 일을 골라주세요")
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(1...store.cycleLength, id: \.self) { i in
                    TomatoIcon(style: sessionStyle(i), size: 18)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(store.cycleLength)번 중 \(store.session)번째")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .cuteSurface(radius: 18, fill: .white)
    }

    /// 끝난 세션 = 딴 토마토, 진행 중 = 복숭아색, 남은 세션 = 흰색 (휴식 중이면 현재 세션도 끝난 것으로)
    private func sessionStyle(_ i: Int) -> TomatoIconStyle {
        if i < store.session || (i == store.session && store.mode != .focus) { return .filled }
        return i == store.session ? .current : .upcoming
    }

    private var nextText: String {
        let next = store.nextMode
        let auto = next == .focus ? store.settings.autoStartFocus : store.settings.autoStartBreak
        return "다음은 \(next.label) \(store.minutesSetting(for: next))분" + (auto ? " · 자동으로 시작해요" : "")
    }
}

/// 집중 중에는 2초 주기로 2.5pt 위아래로 움직임. 동작 줄이기 설정이면 멈춤
struct BobbingMascot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mood: TomatoMood
    let size: CGFloat
    var lineScale: CGFloat = 1
    var simple = false

    var body: some View {
        let active = mood == .focus && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            TomatoMascot(mood: mood, size: size, lineScale: lineScale, simple: simple)
                .offset(y: active ? sin(t * .pi) * 2.5 : 0)
        }
        .id(mood)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: mood)
    }
}
