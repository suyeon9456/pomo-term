import SwiftUI

/// 강아지 테마 타이머 패널. 장면 카드(골든) / 투명 강아지(설이), 발자국 / 털뭉치만 style로 갈림
struct DogTimerPanel: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle

    private var state: MascotState { MascotState(mode: store.mode, isRunning: store.isRunning) }

    var body: some View {
        VStack(spacing: 14) {
            modeTabs

            // 창 높이에 따라 강아지 영역만 줄어듦
            Group {
                switch style.scene {
                case .card: DogSceneCard(style: style, state: state, running: store.isRunning, remaining: store.remaining)
                case .cutout: DogCutout(style: style, state: state)
                }
            }
            .frame(maxWidth: 340, maxHeight: .infinity)
            .layoutPriority(-1)

            VStack(spacing: 4) {
                Text(store.timeString)
                    .font(.system(size: style.timerSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1.2)
                    .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                HStack(spacing: 8) {
                    Text(store.mode == .focus ? "\(store.cycleLength)번 중 \(store.session)번째 집중"
                                              : "\(style.modeName(store.mode)) 시간이에요")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(style.textSecondary)
                    minuteAdjuster
                }
            }

            trail

            controls

            currentTaskCard

            Text(nextText)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(style.textSecondary)
                .padding(.top, -4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: style.panelRadius, style: .circular).fill(style.panel(store.mode)))
        .padding(22)
        .animation(.easeInOut(duration: 0.4), value: store.mode)
    }

    private var modeTabs: some View {
        HStack(spacing: 4) {
            ForEach(TimerMode.allCases, id: \.self) { m in
                let selected = m == store.mode
                Button { store.switchMode(m) } label: {
                    Text(style.modeName(m))
                        .font(.system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if selected { Color.clear.dogCard(style, radius: style.cardRadius - 6, shadow: 0.14, shadowRadius: 8) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: style.cardRadius - 2, style: .circular).fill(Color.white.opacity(0.72)))
    }

    /// − 25분 + (실행 중엔 비활성)
    private var minuteAdjuster: some View {
        let step = AppStore.minuteStep(for: store.mode)
        return HStack(spacing: 0) {
            Button { store.adjustCurrentMinutes(by: -1) } label: {
                Image(systemName: "minus").font(.system(size: 9, weight: .heavy)).frame(width: 22, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(style.modeName(store.mode)) \(step)분 줄이기")
            Text("\(store.minutesSetting(for: store.mode))분")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Button { store.adjustCurrentMinutes(by: 1) } label: {
                Image(systemName: "plus").font(.system(size: 9, weight: .heavy)).frame(width: 22, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(style.modeName(store.mode)) \(step)분 늘리기")
        }
        .foregroundStyle(style.textSecondary)
        .background(Capsule(style: .circular).fill(Color.white.opacity(0.8)))
        .opacity(store.isRunning ? 0.45 : 1)
        .disabled(store.isRunning)
    }

    @ViewBuilder private var trail: some View {
        let accent = style.accent(store.mode)
        switch style.trail {
        case .paws:
            // 발자국 12개, 90° 돌려 지그재그로
            let filled = Int((store.progress * 12).rounded())
            HStack(spacing: 6) {
                ForEach(0..<12, id: \.self) { i in
                    PawIcon(fill: i < filled ? accent : style.trailEmpty, size: 16)
                        .rotationEffect(.degrees(90))
                        .offset(y: i % 2 == 0 ? -4 : 4)
                }
            }
            .frame(height: 26)
            .accessibilityHidden(true)
        case .puffs:
            // 털뭉치 24개 한 줄
            let filled = Int((store.progress * 24).rounded())
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { i in
                    Circle().fill(i < filled ? accent : style.trailEmpty).frame(width: 10, height: 10)
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)
        }
    }

    private var controls: some View {
        let shadow = style.shadow.opacity(0.14)
        return HStack(spacing: 20) {
            Button(action: store.reset) {
                Image(systemName: "arrow.counterclockwise").font(.system(size: 19, weight: .semibold)).foregroundStyle(style.text)
            }
            .buttonStyle(DogCircleButtonStyle(fill: .white, size: 50, shadow: shadow))
            .accessibilityLabel("타이머 초기화")

            Button(action: store.toggle) {
                Image(systemName: store.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: store.isRunning ? 24 : 28))
                    .foregroundStyle(style.textOnAccent)
                    .offset(x: store.isRunning ? 0 : 2)
            }
            .buttonStyle(DogCircleButtonStyle(fill: style.accent(store.mode), size: 76, shadow: style.shadow.opacity(0.25)))
            .accessibilityLabel(store.isRunning ? "일시정지" : "시작")

            Button(action: store.skip) {
                Image(systemName: "forward.end").font(.system(size: 18, weight: .semibold)).foregroundStyle(style.text)
            }
            .buttonStyle(DogCircleButtonStyle(fill: .white, size: 50, shadow: shadow))
            .accessibilityLabel("다음 단계로 건너뛰기")
        }
    }

    private var currentTaskCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(style.currentTaskTitle).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(style.textSecondary)
                Text(store.selectedTodo.map { t in (store.parent(of: t).map { "\($0.title) › " } ?? "") + t.title }
                     ?? style.noTaskText)
                    .font(.system(size: 15, design: .rounded))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(1...store.cycleLength, id: \.self) { i in
                    let s = sessionStyle(i)
                    PawIcon(fill: s.fill, stroke: s.stroke, size: 18)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(store.cycleLength)번 중 \(store.session)번째")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .dogCard(style, radius: style.cardRadius, shadow: 0.08, shadowRadius: 12)
    }

    /// 끝난 세션 / 진행 중 / 남은 세션 (휴식 중이면 현재 세션도 끝난 것으로)
    private func sessionStyle(_ i: Int) -> (fill: Color, stroke: Color?) {
        if i < store.session || (i == store.session && store.mode != .focus) { return style.sessionDone }
        return i == store.session ? style.sessionCurrent : style.sessionUpcoming
    }

    private var nextText: String {
        let next = store.nextMode
        let auto = next == .focus ? store.settings.autoStartFocus : store.settings.autoStartBreak
        return "다음은 \(style.modeName(next)) \(store.minutesSetting(for: next))분" + (auto ? " · 자동으로 시작해요" : "")
    }
}

// MARK: - 설이: 투명 강아지 + 발밑 그림자 (움직임 없음)

private struct DogCutout: View {
    let style: DogStyle
    let state: MascotState

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(style.shadow.opacity(0.16))
                    .frame(width: geo.size.width * 0.6, height: 22)
                    .blur(radius: 5)
                    .offset(y: 6)
                Image(nsImage: DogImages.image(style.mascotImages[state] ?? ""))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    // 위 16%(긴 놀이는 18%)를 비우고 아래에 맞춤
                    .frame(maxWidth: .infinity, maxHeight: h * (state == .longBreak ? 0.82 : 0.84), alignment: .bottom)
                    .accessibilityLabel(style.mascotLabels[state] ?? "")
            }
            .frame(width: geo.size.width, height: h, alignment: .bottom)
        }
        .aspectRatio(340 / 357, contentMode: .fit)
    }
}

// MARK: - 골든: 장면 카드 + 상태 라벨 + 말풍선 (+ 움직임)

private struct DogSceneCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: DogStyle
    let state: MascotState
    let running: Bool
    let remaining: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Color(hex: 0xEBD3AA)
                // 짧은·긴 휴식은 같은 이미지라 같은 장면으로 취급
                let sceneKey = style.mascotImages[state] ?? ""
                AnimatedScene(style: style, state: state, reduceMotion: reduceMotion)
                    .frame(width: w, height: h)
                    .id(sceneKey)
                    .transition(.opacity)

                stateLabel
                    .padding(.leading, w * 0.04)
                    .padding(.top, h * 0.04)

                if let speech = style.speech {
                    bubble(speech.text(state: state, running: running, leftMinutes: (remaining + 59) / 60), width: w)
                        .padding(.top, h * 0.14)
                        .id(bubbleKey)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: w, height: h)
            .animation(.easeOut(duration: 0.6), value: style.mascotImages[state])
            .animation(.easeOut(duration: 0.45), value: bubbleKey)
        }
        .aspectRatio(500 / 540, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .circular))
        .shadow(color: style.shadow.opacity(0.22), radius: 14, y: 12)
    }

    /// 상태가 바뀔 때만 말풍선이 다시 올라옴 (집중 중 남은 분이 바뀌는 건 제외)
    private var bubbleKey: String { "\(state)-\(running)" }

    private var stateLabel: some View {
        let (text, dot): (String, Color) = {
            switch state {
            case .idle: return ("대기 중", Color(hex: 0xE8B04A))
            case .focusing: return ("집중 중", Color(hex: 0x6E9BD6))
            case .shortBreak, .longBreak: return ("휴식 중", Color(hex: 0x7DB86A))
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(text).font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(style.text)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .circular).fill(style.window.opacity(0.94))
            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2))
    }

    /// 대기·휴식은 오른쪽, 집중은 가운데. 원본 이미지에서 말풍선을 지운 자리를 덮음
    private func bubble(_ text: String, width w: CGFloat) -> some View {
        let centered = state == .focusing
        return Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(style.text)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(style.window.opacity(0.96))
                .shadow(color: Color.black.opacity(0.16), radius: 7, y: 4))
            .frame(maxWidth: w * 0.64)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .trailing)
        .padding(.horizontal, centered ? w * 0.18 : 0)
        .padding(.trailing, centered ? 0 : w * 0.04)
        .accessibilityLabel(text)
    }
}

/// 장면 이미지 + 상태별 움직임 (대기: 천천히 확대, 집중: 숨쉬기 + z z Z, 휴식: 통통 걷기)
private struct AnimatedScene: View {
    let style: DogStyle
    let state: MascotState
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    image
                        .scaleEffect(scale(t), anchor: state == .focusing ? UnitPoint(x: 0.55, y: 0.72) : .center)
                        .offset(y: bounce(t))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    if state == .focusing && !reduceMotion {
                        ForEach(0..<3, id: \.self) { i in
                            floatingZ(i, t: t)
                                .position(x: geo.size.width * 0.75, y: geo.size.height * 0.48)
                        }
                    }
                }
            }
        }
    }

    private var image: some View {
        Image(nsImage: DogImages.image(style.mascotImages[state] ?? ""))
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .accessibilityLabel(style.mascotLabels[state] ?? "")
    }

    /// 0~1을 오가는 부드러운 파형
    private func wave(_ t: Double, period: Double) -> Double { 0.5 - 0.5 * cos(2 * .pi * t / period) }

    private func scale(_ t: Double) -> CGFloat {
        guard !reduceMotion else { return 1.04 }
        switch state {
        case .idle: return 1.04 + 0.04 * wave(t, period: 7)
        case .focusing: return 1.04 + 0.025 * wave(t, period: 4.2)
        case .shortBreak, .longBreak: return 1.05
        }
    }

    private func bounce(_ t: Double) -> CGFloat {
        guard !reduceMotion, state == .shortBreak || state == .longBreak else { return 0 }
        return -5 * wave(t, period: 0.62)
    }

    /// z z Z가 1초 간격으로 오른쪽 위로 떠오르며 사라짐 (3초 주기)
    private func floatingZ(_ i: Int, t: Double) -> some View {
        let p = (t + Double(3 - i)).truncatingRemainder(dividingBy: 3) / 3
        let opacity = p < 0.2 ? p / 0.2 : 1 - (p - 0.2) / 0.8
        return Text(i == 2 ? "Z" : "z")
            .font(.system(size: [18, 22, 26][i], weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: 0x5C6B86))
            .scaleEffect(0.6 + 0.6 * p)
            .offset(x: 16 * p, y: -38 * p)
            .opacity(opacity)
            .accessibilityHidden(true)
    }
}
