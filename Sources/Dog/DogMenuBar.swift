import SwiftUI

/// 강아지 테마 메뉴 막대 라벨: 발바닥 + 남은 시간.
/// 어두운 메뉴 막대에서도 보이도록 밝은 바탕 알약으로 그림 (토마토 친구와 같은 이유)
struct DogMenuBarLabel: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle

    var body: some View {
        Image(nsImage: Self.image(style: style, time: store.timeString, mode: store.mode, running: store.isRunning))
            .accessibilityLabel("\(style.appName) \(style.modeName(store.mode)) \(store.timeString)")
    }

    @MainActor
    static func image(style: DogStyle, time: String, mode: TimerMode, running: Bool) -> NSImage {
        let pill = HStack(spacing: 4) {
            PawIcon(fill: style.strong, size: 13)
            Text(time).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .foregroundStyle(style.text)
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 2)
        .background(running ? style.panel(mode) : style.window, in: Capsule(style: .circular))
        .overlay(Capsule(style: .circular).strokeBorder(style.textSecondary.opacity(0.35), lineWidth: 1))

        let renderer = ImageRenderer(content: pill)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = false
        return image
    }
}

/// 강아지 테마 메뉴 막대 팝오버 (PomPhotoMenuBar / GoldenPhotoMenuBar)
struct DogPopover: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle

    private var state: MascotState { MascotState(mode: store.mode, isRunning: store.isRunning) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.mode == .focus ? "집중 · \(store.session)번째" : style.modeName(store.mode))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(style.strong)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(style.panel(store.mode), in: RoundedRectangle(cornerRadius: 12, style: .circular))
                Spacer()
                SettingsLink {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("설정")
            }

            HStack(spacing: 12) {
                menuBarPicture
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.timeString)
                        .font(.system(size: style.scene == .card ? 46 : 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.9)
                        .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                    Text(caption)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(style.textSecondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, style.scene == .card ? 10 : 8)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.scene == .card ? style.sidebar : style.panel(store.mode),
                        in: RoundedRectangle(cornerRadius: style.cardRadius + 2, style: .circular))

            DogProgressBar(fraction: store.progress, fill: style.accent(store.mode), track: style.track, height: 8)

            Text(store.selectedTodo.map { t in (store.parent(of: t).map { "\($0.title) › " } ?? "") + t.title }
                 ?? style.noTaskText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .lineLimit(1)

            HStack(spacing: 10) {
                Button(action: store.toggle) {
                    Text(store.isRunning ? "잠깐 멈춤" : "시작하기")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(style.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(DogButtonStyle(fill: style.accent(store.mode), radius: style.cardRadius - 4,
                                            shadow: style.accent(store.mode).opacity(0.35)))
                Button(action: store.skip) {
                    Text("건너뛰기")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(DogButtonStyle(fill: style.softButton, radius: style.cardRadius - 4))
            }

            nextList

            HStack(spacing: 4) {
                Button { store.openMainWindow?() } label: {
                    Text("메인 창 열기").font(.system(size: 14, weight: .semibold, design: .rounded)).frame(height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text("·").foregroundStyle(style.textSecondary)
                Button { store.toggleMiniTimer?() } label: {
                    Text("미니 타이머").font(.system(size: 14, weight: .semibold, design: .rounded)).frame(height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                if store.settings.globalHotKey {
                    Text("⌘ ⇧ P").font(.system(size: 12, design: .rounded)).foregroundStyle(style.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .foregroundStyle(style.text)
        .background(style.window)
        .preferredColorScheme(.light)
    }

    /// 골든: 둥근 모서리로 자른 사진 / 설이: 투명 PNG를 그대로
    @ViewBuilder private var menuBarPicture: some View {
        let image = Image(nsImage: DogImages.image(style.menuBarImage)).resizable().interpolation(.high)
        switch style.scene {
        case .card:
            image.scaledToFill()
                .frame(width: 118, height: 96)
                .background(Color(hex: 0xF7F1EA))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .circular))
                .accessibilityLabel(style.menuBarImageLabel)
        case .cutout:
            image.scaledToFit()
                .frame(width: 120, height: 92)
                .accessibilityLabel(style.menuBarImageLabel)
        }
    }

    private var caption: String {
        switch state {
        case .focusing: return style.popoverCaption
        case .idle: return "같이 시작할까요?"
        case .shortBreak, .longBreak: return store.isRunning ? "\(style.modeName(store.mode)) 중이에요" : "잠깐 쉬어가요"
        }
    }

    /// 오늘 목록에서 지금 집중 대상을 뺀 열린 작업 2개
    private var nextList: some View {
        let items = store.rows(.today)
            .filter { !$0.item.isDone && $0.item.id != store.selectedTodo?.id && store.openChildrenCount($0.item) == 0 }
            .prefix(2)
        return VStack(alignment: .leading, spacing: 6) {
            Text(style.nextListTitle).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(style.textSecondary)
            if items.isEmpty {
                Text("남은 할 일이 없어요").font(.system(size: 13, design: .rounded)).foregroundStyle(style.textSecondary)
            }
            ForEach(Array(items)) { row in
                let counts = store.pomoCounts(row.item)
                Button { store.select(row.item) } label: {
                    HStack(spacing: 10) {
                        Text(row.item.project.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.vertical, 1)
                            .padding(.horizontal, 8)
                            .background(style.chip(row.item.project), in: RoundedRectangle(cornerRadius: 8, style: .circular))
                            .fixedSize()
                        Text(row.item.title).font(.system(size: 14, design: .rounded)).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(counts.done)/\(counts.est)").font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(style.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .dogCard(style, radius: style.cardRadius - 4, shadow: 0.07)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(row.item.title) 집중하기")
            }
        }
    }
}

/// 강아지 테마 미니 타이머 (320×96 알약)
struct DogMiniTimer: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
    var onOpenMain: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            progressRing.frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.timeString)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                Text(store.selectedTodo?.title ?? (store.mode == .focus ? style.noTaskText : "\(style.modeName(store.mode)) 시간이에요"))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(style.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: store.toggle) {
                Image(systemName: store.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(style.textOnAccent)
                    .offset(x: store.isRunning ? 0 : 1)
            }
            .buttonStyle(DogCircleButtonStyle(fill: style.accent(store.mode), size: 50, shadow: style.accent(store.mode).opacity(0.4)))
            .accessibilityLabel(store.isRunning ? "일시정지" : "시작")

            Button(action: onOpenMain) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("메인 창으로 펼치기")
        }
        .foregroundStyle(style.text)
        .padding(.horizontal, 12)
        .frame(width: 320, height: 96)
        .background(Capsule(style: .circular).fill(style.window).shadow(color: style.shadow.opacity(0.18), radius: 14, y: 10))
        .contentShape(Capsule(style: .circular))
        .onTapGesture(count: 2, perform: onOpenMain)
        .contextMenu {
            Button("메인 창 열기", action: onOpenMain)
            Button("미니 타이머 닫기", action: onClose)
        }
        // 부드러운 그림자가 잘리지 않도록 여백
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 26)
        .preferredColorScheme(.light)
    }

    /// 골든: 링(바탕 track, 진행 accent) / 설이: 털뭉치 12개 원형
    @ViewBuilder private var progressRing: some View {
        let accent = style.accent(store.mode)
        switch style.trail {
        case .paws:
            ZStack {
                Circle().fill(style.sidebar).frame(width: 64, height: 64)
                Circle().stroke(style.track, lineWidth: 5).frame(width: 64, height: 64)
                Circle().trim(from: 0, to: max(0, min(1, store.progress)))
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)
                DogAvatar(file: style.avatarSleep, size: 54)
            }
        case .puffs:
            let filled = Int((store.progress * 12).rounded())
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    let a = (-90 + Double(i) * 30) * .pi / 180
                    Circle().fill(i < filled ? accent : style.trailEmpty)
                        .frame(width: 8, height: 8)
                        .offset(x: 33 * cos(a), y: 33 * sin(a))
                }
                DogAvatar(file: style.avatarSleep, size: 52, background: Color(hex: 0xF7E8E2))
            }
            .accessibilityHidden(true)
        }
    }
}
