import SwiftUI

/// 귀여운 테마 메뉴 막대 라벨: 작은 토마토 + 남은 시간.
/// 시안의 반투명 갈색 바탕은 어두운 메뉴 막대에서 안 보여서, 밝은 바탕 + ink 테두리 알약으로 그림
struct CuteMenuBarLabel: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Image(nsImage: Self.image(time: store.timeString, mode: store.mode, running: store.isRunning))
            .accessibilityLabel("토마토 타임 \(store.mode.label) \(store.timeString)")
    }

    @MainActor
    static func image(time: String, mode: TimerMode, running: Bool) -> NSImage {
        let renderer = ImageRenderer(content: CuteMenuBarPill(time: time, mode: mode, running: running))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = false
        return image
    }
}

struct CuteMenuBarPill: View {
    let time: String
    let mode: TimerMode
    let running: Bool

    var body: some View {
        HStack(spacing: 4) {
            TomatoIcon(style: mode == .focus ? .filled : .current, size: 14)
            Text(time).font(.system(size: 12, weight: .semibold)).monospacedDigit()
        }
        .foregroundStyle(Color.cute.ink)
        .padding(.leading, 4)
        .padding(.trailing, 7)
        .padding(.vertical, 1)
        .background(running ? mode.cuteTab : Color.cute.window, in: Capsule(style: .circular))
        .overlay(Capsule(style: .circular).strokeBorder(Color.cute.ink, lineWidth: 1.5))
    }
}

/// 귀여운 테마 메뉴 막대 팝오버 (reference/CuteMenuBar.dc.html)
struct CutePopover: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(statusChip)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 10)
                    .cuteSurface(radius: 10, fill: store.mode.cuteTab)
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

            HStack(spacing: 14) {
                BobbingMascot(mood: TomatoMood.of(mode: store.mode, running: store.isRunning), size: 76, lineScale: 1.4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.timeString)
                        .font(.system(size: 50, weight: .light))
                        .monospacedDigit()
                        .tracking(-1)
                        .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                    Text(shortBubble)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cute.inkSecondary)
                }
            }

            CuteProgressBar(fraction: store.progress)

            Text(store.selectedTodo.map { t in (store.parent(of: t).map { "\($0.title) › " } ?? "") + t.title }
                 ?? "목록에서 집중할 일을 골라주세요")
                .font(.system(size: 14))
                .lineLimit(1)

            HStack(spacing: 10) {
                Button(action: store.toggle) {
                    HStack(spacing: 6) {
                        Image(systemName: store.isRunning ? "pause.fill" : "play.fill").font(.system(size: 12))
                        Text(store.isRunning ? "잠깐 멈춤" : "시작하기").font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(CuteButtonStyle(fill: store.mode.cuteTab))
                Button(action: store.skip) {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.end.fill").font(.system(size: 12))
                        Text("건너뛰기").font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(CuteButtonStyle(fill: .white))
            }

            nextList

            HStack(spacing: 4) {
                Button { store.openMainWindow?() } label: {
                    Text("메인 창 열기").font(.system(size: 14, weight: .semibold)).frame(height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text("·").foregroundStyle(Color.cute.inkSecondary)
                Button { store.toggleMiniTimer?() } label: {
                    Text("미니 타이머").font(.system(size: 14, weight: .semibold)).frame(height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                if store.settings.globalHotKey {
                    Text("⌘ ⇧ P").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.cute.inkSecondary)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .foregroundStyle(Color.cute.ink)
        .background(Color.cute.window)
        .preferredColorScheme(.light)
    }

    private var statusChip: String {
        store.mode == .focus ? "집중 · \(store.session)번째 토마토" : store.mode.label
    }

    private var shortBubble: String {
        let leftMin = (store.remaining + 59) / 60
        switch (store.mode == .focus, store.isRunning) {
        case (true, false): return "준비됐어? 같이 시작하자!"
        case (true, true): return "쉿, \(leftMin)분만 더!"
        case (false, false): return "잠깐 쉬어갈까?"
        case (false, true): return "물 한 잔 마시고 쉬는 중~"
        }
    }

    /// 다음에 키울 토마토: 오늘 목록에서 지금 집중 대상을 뺀 열린 작업 2개
    private var nextList: some View {
        let items = store.rows(.today)
            .filter { !$0.item.isDone && $0.item.id != store.selectedTodo?.id && store.openChildrenCount($0.item) == 0 }
            .prefix(2)
        return VStack(alignment: .leading, spacing: 4) {
            Text("다음에 키울 토마토")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cute.inkSecondary)
                .padding(.bottom, 2)
            if items.isEmpty {
                Text("남은 할 일이 없어요").font(.system(size: 13)).foregroundStyle(Color.cute.inkSecondary)
            }
            ForEach(Array(items)) { row in
                let counts = store.pomoCounts(row.item)
                Button { store.select(row.item) } label: {
                    HStack(spacing: 10) {
                        ProjectChip(project: row.item.project, fontSize: 11)
                        Text(row.item.title).font(.system(size: 14)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(counts.done)/\(counts.est)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.cute.inkSecondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .cuteSurface(radius: 14, fill: .white, border: .cute.rowBorder)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(row.item.title) 집중하기")
            }
        }
        .padding(.top, 4)
    }
}
