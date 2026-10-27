import SwiftUI

/// 메뉴 막대 라벨: `● 18:42` 알약.
/// MenuBarExtra는 라벨의 텍스트 색을 지우므로 컬러 이미지(템플릿 아님)로 렌더링해서 넣음
struct MenuBarLabel: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Image(nsImage: Self.image(time: store.timeString, mode: store.mode, running: store.isRunning))
            .accessibilityLabel("pomo \(store.mode.key) \(store.timeString)")
    }

    @MainActor
    static func image(time: String, mode: TimerMode, running: Bool) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarPill(time: time, mode: mode, running: running))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = false
        return image
    }
}

struct MenuBarPill: View {
    let time: String
    let mode: TimerMode
    let running: Bool

    var body: some View {
        let color = running ? mode.accent : Color.term.dim
        Text("\(running ? "●" : "❚❚") \(time)")
            .font(.term(12, .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
    }
}

/// 메뉴 막대 팝오버 (reference/TermMenuBar.dc.html)
struct MenuBarPopover: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("pomo — status")
                .font(.term(11))
                .foregroundStyle(Color.term.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.term.titlebar)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.term.border).frame(height: 1) }

            VStack(alignment: .leading, spacing: 12) {
                status
                buttons
                next
                footer
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .font(.term(12))
        .foregroundStyle(Color.term.text)
        .frame(width: 320)
        .background(Color.term.window)
        .preferredColorScheme(.dark)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("$ pomo status").foregroundStyle(Color.term.accentFocus)
            HStack(spacing: 0) {
                Text("mode   ").foregroundStyle(Color.term.muted)
                Text(store.mode.upper).font(.term(12, .bold)).foregroundStyle(store.mode.accent)
                Text(" (\(store.session)/\(store.cycleLength))").foregroundStyle(Color.term.dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("remain ").foregroundStyle(Color.term.muted)
                Text(store.timeString)
                    .font(.term(28, .extraBold))
                    .tracking(-0.03 * 28)
                    .foregroundStyle(Color.term.bright)
                    .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
            }
            Text(store.asciiBar(width: 18)).foregroundStyle(store.mode.accent).lineLimit(1)
            HStack(spacing: 0) {
                Text("task   ").foregroundStyle(Color.term.muted)
                Text(store.selectedTodo?.title ?? "(none)").foregroundStyle(Color.term.bright)
            }
            .lineLimit(1)
        }
        .lineSpacing(4)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(action: store.toggle) {
                Text(store.isRunning ? "❚❚ pause" : "▶ start")
                    .font(.term(12, .extraBold))
                    .foregroundStyle(Color.term.window)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(store.mode.accent, in: RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isRunning ? "일시정지" : "시작")
            popoverButton("» skip", label: "건너뛰기", action: store.skip)
            popoverButton("↗ open", label: "메인 창 열기") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func popoverButton(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.term(12))
                .foregroundStyle(Color.term.text)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.term.borderStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// 현재 집중 대상을 뺀 미완료 할 일 3개. 번호는 메인 창과 같은 순서 기준
    private var nextItems: [(number: Int, item: TodoItem)] {
        store.orderedTodos.enumerated()
            .filter { !$0.element.isDone && $0.element.id != store.selectedTodo?.id }
            .prefix(3)
            .map { ($0.offset + 1, $0.element) }
    }

    private var next: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("$ pomo next").foregroundStyle(Color.term.accentFocus)
            if nextItems.isEmpty {
                Text("(empty)").foregroundStyle(Color.term.muted).frame(minHeight: 36)
            }
            ForEach(nextItems, id: \.item.id) { entry in
                Button { store.select(entry.item) } label: {
                    HStack(spacing: 10) {
                        Text("\(entry.number)").foregroundStyle(Color.term.muted)
                        Text("[ ]")
                        Text(entry.item.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(AppStore.pomoBar(entry.item)).tracking(1).foregroundStyle(Color.term.error)
                    }
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(entry.item.title) 집중하기")
            }
        }
        .padding(.top, 10)
        .overlay(alignment: .top) { DashedLine(color: .term.border) }
    }

    private var footer: some View {
        HStack {
            Text("today: \(store.todayCount) pomo · \(store.focusTimeText)")
            Spacer()
        }
        .font(.term(11))
        .foregroundStyle(Color.term.dim)
        .padding(.top, 8)
        .overlay(alignment: .top) { DashedLine(color: .term.border) }
    }
}
