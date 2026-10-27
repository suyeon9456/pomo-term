import SwiftUI

/// 메인 창 (reference/TermMain.dc.html)
struct MainWindowView: View {
    @EnvironmentObject var store: AppStore

    private static let tasksMinWidth: CGFloat = 460
    private static let timerWidth: CGFloat = 420

    var body: some View {
        VStack(spacing: 0) {
            TitleBar()
            GeometryReader { geo in
                // 폭이 모자라면 타이머 패널을 아래로 내림 (flex-wrap)
                if geo.size.width >= Self.tasksMinWidth + Self.timerWidth {
                    HStack(alignment: .top, spacing: 0) {
                        TasksPane(scrolls: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Rectangle().fill(Color.term.border).frame(width: 1)
                        TimerPane()
                            .frame(width: Self.timerWidth)
                            .frame(maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            TasksPane(scrolls: false)
                            Rectangle().fill(Color.term.border).frame(height: 1)
                            TimerPane()
                        }
                    }
                }
            }
            CommandLineBar()
            StatusBar()
        }
        .font(.term(14))
        .foregroundStyle(Color.term.text)
        .background(Color.term.window)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .frame(minWidth: 520, minHeight: 600)
    }
}

// MARK: - Title bar

private struct TitleBar: View {
    var body: some View {
        // 신호등 버튼은 시스템 것을 그대로 사용
        Text("pomo — ~/today — zsh — 128×40")
            .font(.term(12))
            .foregroundStyle(Color.term.dim)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Color.term.titlebar)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.term.border).frame(height: 1) }
    }
}

// MARK: - Tasks pane

private struct TasksPane: View {
    @EnvironmentObject var store: AppStore
    let scrolls: Bool
    @State private var editingPeriod: TodoItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(ListTab.allCases, id: \.self) { tab in
                    ListTabButton(tab: tab)
                }
                Spacer(minLength: 12)
                Text("\(store.openCount) open · \(store.doneCount) done · ~\(store.remainingPomodoros) pomo left")
                    .font(.term(13))
                    .foregroundStyle(Color.term.dim)
                    .lineLimit(1)
            }

            let list = store.orderedTodos
            // 목록에 기간 할 일이 하나라도 있으면 period 칸을 보여줌
            let showsPeriod = list.contains(where: \.isScheduled)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("#").frame(width: 24, alignment: .trailing)
                    Text("st").frame(width: 44, alignment: .leading)
                    Text("title").frame(maxWidth: .infinity, alignment: .leading)
                    if showsPeriod { Text("period").frame(width: TaskRow.periodWidth, alignment: .leading) }
                    Text("tag · pomo")
                }
                .font(.term(12))
                .foregroundStyle(Color.term.muted)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) { DashedLine(color: .term.border) }

                if scrolls {
                    ScrollView { rows(list, showsPeriod: showsPeriod) }
                } else {
                    rows(list, showsPeriod: showsPeriod)
                }
            }
            .frame(maxHeight: scrolls ? .infinity : nil, alignment: .top)

            LogView()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .sheet(item: $editingPeriod) { item in
            PeriodEditor(item: item).environmentObject(store)
        }
    }

    private func rows(_ list: [TodoItem], showsPeriod: Bool) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, item in
                TaskRow(number: i + 1, item: item, showsPeriod: showsPeriod) { editingPeriod = item }
            }
            if list.isEmpty {
                Text(store.listTab == .today ? "할 일이 없어요 — add <할 일> 로 추가"
                                             : "기간 할 일이 없어요 — add <할 일> ~M/D 로 추가")
                    .font(.term(13))
                    .foregroundStyle(Color.term.muted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.leading, 36)
            }
        }
    }
}

private struct ListTabButton: View {
    @EnvironmentObject var store: AppStore
    let tab: ListTab

    var body: some View {
        let selected = store.listTab == tab
        Button { store.listTab = tab } label: {
            Text(tab.fileName)
                .font(.term(13, .bold))
                .foregroundStyle(selected ? Color.term.accentFocus : Color.term.dim)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(selected ? Color.term.tabActive : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? Color.term.accentFocus : Color.term.borderStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(tab == .today ? "1" : "2", modifiers: .command)
        .accessibilityLabel(tab == .today ? "오늘 할 일" : "기간 할 일")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct TaskRow: View {
    @EnvironmentObject var store: AppStore
    let number: Int
    let item: TodoItem
    let showsPeriod: Bool
    let onEditPeriod: () -> Void

    static let periodWidth: CGFloat = 150

    private var isActive: Bool { store.selectedTodo?.id == item.id }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.term(13))
                .foregroundStyle(Color.term.muted)
                .frame(width: 24, alignment: .trailing)

            Button { store.toggleDone(item) } label: {
                Text(item.isDone ? "[x]" : "[ ]")
                    .font(.term(14, .bold))
                    .foregroundStyle(item.isDone ? Color.term.accentFocus : Color.term.text)
                    .frame(width: 44, height: 40, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "\(item.title) 완료 취소" : "\(item.title) 완료로 표시")

            Button { store.select(item) } label: {
                HStack(spacing: 0) {
                    Text(item.title)
                        .strikethrough(item.isDone, color: Color.term.muted)
                        .foregroundStyle(item.isDone ? Color.term.muted : isActive ? Color.white : Color.term.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isActive {
                        Text("  ◀ now").font(.term(14, .bold)).foregroundStyle(Color.term.accentFocus)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.title) 집중하기")

            if showsPeriod {
                period.frame(width: Self.periodWidth, alignment: .leading)
            }

            Text("#\(item.project.rawValue)")
                .font(.term(13))
                .foregroundStyle(item.project.color)
            Text(AppStore.pomoBar(item))
                .font(.term(13))
                .tracking(1)
                .foregroundStyle(Color.term.error)
                .frame(minWidth: 52, alignment: .leading)
        }
        .frame(minHeight: 44)
        .background(isActive ? Color.term.activeRow : Color.clear)
        .overlay(alignment: .bottom) { DashedLine(color: .term.borderDashed) }
        .contextMenu { menu }
    }

    @ViewBuilder private var period: some View {
        if let due = item.dueDate {
            let days = Period.daysLeft(until: due)
            // 마감이 지났거나 오늘이면 빨강, 3일 이내면 앰버
            let ddayColor: Color = item.isDone ? .term.muted : days <= 0 ? .term.error : days <= 3 ? .term.accentBreak : .term.muted
            HStack(spacing: 6) {
                Text(Period.text(start: item.startDate, due: due)).foregroundStyle(item.isDone ? Color.term.muted : Color.term.dim)
                Text(Period.ddayText(until: due)).foregroundStyle(ddayColor)
            }
            .font(.term(12))
            .lineLimit(1)
            .accessibilityLabel("기간 \(Period.text(start: item.startDate, due: due)), \(Period.ddayText(until: due))")
        } else {
            Text("")
        }
    }

    @ViewBuilder private var menu: some View {
        if !item.isDone { Button("집중하기") { store.select(item) } }
        Button(item.isDone ? "미완료로 되돌리기" : "완료") { store.toggleDone(item) }
        Divider()
        Button(item.isScheduled ? "기간 변경…" : "기간 설정…", action: onEditPeriod)
        if item.isScheduled { Button("기간 해제 (오늘 할 일로)") { store.setPeriod(item, start: nil, due: nil) } }
        Picker("태그", selection: Binding(get: { item.project },
                                         set: { p in store.update(item) { $0.project = p } })) {
            ForEach(Project.allCases, id: \.self) { Text("#\($0.rawValue)").tag($0) }
        }
        Picker("예상 뽀모도로", selection: Binding(get: { item.estimatedPomodoros },
                                             set: { n in store.update(item) { $0.estimatedPomodoros = n } })) {
            ForEach(1...8, id: \.self) { Text("\($0)").tag($0) }
        }
        Divider()
        Button("삭제", role: .destructive) { store.delete(item) }
    }
}

/// 우클릭 → 기간 설정… 에서 여는 시트
struct PeriodEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let item: TodoItem

    @State private var hasStart: Bool
    @State private var start: Date
    @State private var due: Date

    init(item: TodoItem) {
        self.item = item
        let today = Period.startOfDay(Date())
        _hasStart = State(initialValue: item.startDate != nil)
        _start = State(initialValue: item.startDate ?? today)
        _due = State(initialValue: item.dueDate ?? Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today)
    }

    private var isValid: Bool { !hasStart || Period.startOfDay(start) <= Period.startOfDay(due) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("── period ───────").font(.term(13, .bold)).foregroundStyle(Color.term.accentFocus)
            Text(item.title).foregroundStyle(Color.term.bright).lineLimit(2)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Toggle("start", isOn: $hasStart).toggleStyle(.checkbox)
                    DatePicker("", selection: $start, displayedComponents: .date).labelsHidden().disabled(!hasStart)
                }
                GridRow {
                    Text("due").foregroundStyle(Color.term.dim)
                    DatePicker("", selection: $due, displayedComponents: .date).labelsHidden()
                }
            }

            Text(isValid ? "\(Period.text(start: hasStart ? start : nil, due: due))  \(Period.ddayText(until: due))"
                         : "✗ 시작일이 마감일보다 늦어요")
                .font(.term(12))
                .foregroundStyle(isValid ? Color.term.dim : Color.term.error)

            HStack(spacing: 8) {
                if item.isScheduled {
                    OutlineButton(title: "기간 해제", label: "기간 해제", height: 36, fontSize: 13) {
                        store.setPeriod(item, start: nil, due: nil)
                        dismiss()
                    }
                }
                Spacer()
                OutlineButton(title: "취소", label: "취소", height: 36, fontSize: 13) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    store.setPeriod(item, start: hasStart ? start : nil, due: due)
                    dismiss()
                } label: {
                    Text("저장")
                        .font(.term(13, .extraBold))
                        .foregroundStyle(Color.term.window)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(isValid ? Color.term.accentFocus : Color.term.muted, in: RoundedRectangle(cornerRadius: 4))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .font(.term(13))
        .foregroundStyle(Color.term.text)
        .padding(22)
        .frame(width: 400)
        .background(Color.term.window)
        .preferredColorScheme(.dark)
    }
}

private struct LogView: View {
    @EnvironmentObject var store: AppStore

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("── log ─────────────").font(.term(12, .bold)).foregroundStyle(Color.term.accentFocus)
            ForEach(store.log) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(Self.timeFormatter.string(from: entry.time))
                        .foregroundStyle(Color.term.muted)
                    Text(entry.text)
                        .foregroundStyle(entry.kind.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .lineSpacing(4)
            }
        }
        .font(.term(13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .overlay(alignment: .top) { Rectangle().fill(Color.term.border).frame(height: 1) }
    }
}

// MARK: - Timer pane

private struct TimerPane: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let accent = store.mode.accent
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("── timer ───────").font(.term(13, .bold)).foregroundStyle(Color.term.accentFocus)
                Spacer()
                Text("session \(store.session)/\(store.cycleLength)").font(.term(13)).foregroundStyle(Color.term.dim)
            }

            HStack(spacing: 6) {
                ForEach(TimerMode.allCases, id: \.self) { m in
                    let selected = m == store.mode
                    Button { store.switchMode(m) } label: {
                        Text(store.tabLabel(for: m))
                            .font(.term(13, .bold))
                            .foregroundStyle(selected ? m.accent : Color.term.dim)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(selected ? Color.term.tabActive : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? m.accent : Color.term.borderStrong))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("$ pomo \(store.mode.key) --running=\(store.isRunning ? "true" : "false")")
                    .font(.term(13))
                Text(store.timeString)
                    .font(.term(112, .extraBold))
                    .tracking(-0.04 * 112)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("남은 시간 \(store.remaining / 60)분 \(store.remaining % 60)초")
                Text(store.asciiBar(width: 24))
                    .font(.term(15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(accent)
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 4) {
                infoLine("task  ", store.selectedTodo?.title ?? "(none) — focus <#> 로 선택")
                infoLine("next  ", store.nextText)
                HStack(spacing: 0) {
                    Text("cycle ").foregroundStyle(Color.term.muted)
                    Text(store.cycleBar).tracking(2).foregroundStyle(Color.term.error)
                }
            }
            .font(.term(13))
            .lineSpacing(5)

            HStack(spacing: 10) {
                Button(action: store.toggle) {
                    Text(store.isRunning ? "❚❚ pause" : "▶ start")
                        .font(.term(14, .extraBold))
                        .foregroundStyle(Color.term.window)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(accent, in: RoundedRectangle(cornerRadius: 4))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.isRunning ? "일시정지" : "시작")
                OutlineButton(title: "↺ reset", label: "초기화", action: store.reset)
                OutlineButton(title: "» skip", label: "건너뛰기", action: store.skip)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("commands").font(.term(12, .bold)).foregroundStyle(Color.term.text)
                Text("start · pause · reset · skip")
                Text("add <할 일> [M/D~M/D] · done <#> · focus <#>")
                Text("ls today|sched · due <#> <M/D~M/D> (해제 -)")
                Text("mode focus|short|long · mini · clear · help")
            }
            .font(.term(12))
            .foregroundStyle(Color.term.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.term.border))
        }
        .padding(.top, 18)
        .padding(.horizontal, 26)
        .padding(.bottom, 22)
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label).foregroundStyle(Color.term.muted)
            Text(value).foregroundStyle(Color.term.bright).lineLimit(1)
        }
    }
}

struct OutlineButton: View {
    let title: String
    let label: String
    var height: CGFloat = 44
    var fontSize: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.term(fontSize, .medium))
                .foregroundStyle(Color.term.text)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.term.borderStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(label)
    }
}

// MARK: - Command line & status bar

private struct CommandLineBar: View {
    @EnvironmentObject var store: AppStore
    @State private var command = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("❯").font(.term(15, .extraBold)).foregroundStyle(Color.term.accentFocus)
            TextField("", text: $command,
                      prompt: Text("명령어 입력 (예: add 리팩터링, done 2, start)").foregroundColor(Color.term.muted))
                .textFieldStyle(.plain)
                .font(.term(14))
                .foregroundStyle(Color.term.bright)
                .focused($focused)
                .onSubmit {
                    store.run(command: command)
                    command = ""
                }
                .accessibilityLabel("명령어 입력")
        }
        .frame(height: 32)
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(Color.term.cmdline)
        .overlay(alignment: .top) { Rectangle().fill(Color.term.border).frame(height: 1) }
        .onAppear { focused = true }
    }
}

private struct StatusBar: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            cell(store.mode.upper, fg: .term.window, bg: store.mode.accent)
            cell(store.timeString, fg: .term.bright, bg: .term.border)
            cell("⎇ \(store.listTab.rawValue)", fg: .term.dim, weight: .medium)
            Spacer(minLength: 0)
            cell("\(store.todayCount) pomo · \(store.focusTimeText)", fg: .term.dim, weight: .medium)
            cell(Self.dateText, fg: .term.bright, bg: .term.border)
        }
        .font(.term(12, .bold))
        .frame(height: 28)
        .background(Color.term.titlebar)
    }

    private static var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d MMM"
        return f.string(from: Date())
    }

    private func cell(_ text: String, fg: Color, bg: Color = .clear, weight: TermWeight = .bold) -> some View {
        Text(text)
            .font(.term(12, weight))
            .foregroundStyle(fg)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .background(bg)
    }
}

// MARK: - Shared pieces

struct DashedLine: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .frame(height: 1)
    }
}
