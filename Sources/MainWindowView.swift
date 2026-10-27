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

            // 접힌 스토리의 하위 태스크는 숨김 (번호는 그대로 유지)
            let collapsed = Set(store.todos.filter(\.isCollapsed).map(\.id))
            let list = store.rows(store.listTab).filter { row in row.item.parentID.map { !collapsed.contains($0) } ?? true }
            // 목록에 기간 할 일이 하나라도 있으면 period 칸을 보여줌
            let showsPeriod = list.contains(where: \.item.isScheduled)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("#").frame(width: TaskRow.numberWidth, alignment: .trailing)
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

    private func rows(_ list: [ListRow], showsPeriod: Bool) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(lines(list)) { line in
                switch line {
                case .task(let row):
                    TaskRow(row: row, showsPeriod: showsPeriod) { editingPeriod = row.item }
                case .addSub(let storyID):
                    InlineAddRow(target: .sub(storyID))
                }
            }
            InlineAddRow(target: .top) { added in
                // scheduled에는 기간이 필요하므로 추가하자마자 기간 설정 창을 엶
                if store.listTab == .scheduled { editingPeriod = added }
            }
        }
    }
}

/// 목록 안에서 바로 입력하는 줄. 평소엔 "+ 할 일 추가…", 누르면 입력칸.
/// Enter로 추가하고 입력칸은 그대로 남아 연달아 추가, Esc나 빈 칸으로 포커스를 잃으면 닫힘
private struct InlineAddRow: View {
    @EnvironmentObject var store: AppStore
    let target: InlineAdd
    var onAdded: (TodoItem) -> Void = { _ in }
    @State private var text = ""
    @FocusState private var focused: Bool

    private var isEditing: Bool { store.inlineAdd == target }
    private var isSub: Bool { target != .top }

    private var placeholder: String {
        if isSub { return "태스크 추가…" }
        return store.listTab == .scheduled ? "기간 할 일 추가… (추가 후 기간 설정)" : "할 일 추가…"
    }

    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: TaskRow.numberWidth, height: 1)
            Text("+")
                .font(.term(14, .bold))
                .foregroundStyle(isEditing ? Color.term.accentFocus : Color.term.muted)
                .frame(width: 44, alignment: .leading)
            HStack(spacing: 0) {
                Color.clear.frame(width: 14 - 6 + 12, height: 1) // 접기 버튼 자리
                if isSub { Text("└ ").foregroundStyle(Color.term.muted) }
                if isEditing {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.term.muted))
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.term.bright)
                        .focused($focused)
                        .onSubmit(submit)
                        .onExitCommand(perform: close)
                        .onAppear { DispatchQueue.main.async { focused = true } }
                        .onChange(of: focused) { isFocused in
                            if !isFocused && text.trimmingCharacters(in: .whitespaces).isEmpty { close() }
                        }
                        .accessibilityLabel(placeholder)
                } else {
                    Text(placeholder).foregroundStyle(Color.term.muted)
                }
                Spacer(minLength: 0)
            }
        }
        .font(.term(14))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { store.beginAdd(target) } }
        .accessibilityAddTraits(isEditing ? [] : .isButton)
    }

    private func submit() {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { close(); return }
        switch target {
        case .top:
            if let item = store.addTodo(title, period: store.listTab == .scheduled ? Self.defaultPeriod : nil) {
                onAdded(item)
            }
        case .sub(let id):
            if let story = store.todos.first(where: { $0.id == id }), let item = store.addSubtask(to: story, title) {
                onAdded(item)
            }
        }
        text = ""
        focused = true
    }

    private func close() {
        text = ""
        if store.inlineAdd == target { store.inlineAdd = nil }
    }

    /// scheduled 탭에서 추가할 때의 임시 기간 (오늘부터 일주일). 바로 뜨는 기간 설정 창에서 바꿈
    private static var defaultPeriod: (start: Date?, due: Date) {
        let today = Period.startOfDay(Date())
        return (nil, Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today)
    }
}

/// 목록의 한 줄: 할 일 행, 또는 스토리의 마지막 태스크 아래에 끼워 넣는 태스크 입력줄
private enum ListLine: Identifiable {
    case task(ListRow)
    case addSub(UUID)

    var id: String {
        switch self {
        case .task(let row): return row.id.uuidString
        case .addSub(let storyID): return "add-\(storyID.uuidString)"
        }
    }
}

extension TasksPane {
    fileprivate func lines(_ list: [ListRow]) -> [ListLine] {
        guard case .sub(let storyID) = store.inlineAdd else { return list.map(ListLine.task) }
        var out: [ListLine] = []
        for (i, row) in list.enumerated() {
            out.append(.task(row))
            let story = row.depth == 0 ? row.item.id : row.item.parentID
            let nextIsChild = i + 1 < list.count && list[i + 1].depth == 1
            if story == storyID && !nextIsChild { out.append(.addSub(storyID)) }
        }
        return out
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
    let row: ListRow
    let showsPeriod: Bool
    let onEditPeriod: () -> Void
    @State private var confirmingDone = false
    @State private var hovering = false

    static let periodWidth: CGFloat = 150
    static let numberWidth: CGFloat = 36

    private var item: TodoItem { row.item }
    private var isActive: Bool { store.selectedTodo?.id == item.id }
    private var isStory: Bool { row.depth == 0 && store.hasChildren(item) }

    var body: some View {
        HStack(spacing: 12) {
            Text(row.number)
                .font(.term(13))
                .foregroundStyle(Color.term.muted)
                .frame(width: Self.numberWidth, alignment: .trailing)

            Button(action: toggleDone) {
                Text(item.isDone ? "[x]" : "[ ]")
                    .font(.term(14, .bold))
                    .foregroundStyle(item.isDone ? Color.term.accentFocus : Color.term.text)
                    .frame(width: 44, height: 40, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "\(item.title) 완료 취소" : "\(item.title) 완료로 표시")
            .confirmationDialog("열린 태스크 \(store.openChildrenCount(item))개가 있어요", isPresented: $confirmingDone) {
                Button("태스크까지 모두 완료") { store.toggleDone(item, includeTasks: true) }
                Button("스토리만 완료") { store.toggleDone(item) }
                Button("취소", role: .cancel) {}
            } message: {
                Text("\(item.title)을(를) 완료로 표시할까요?")
            }

            // 스토리 접기/펼치기 자리. 하위 태스크가 없으면 빈칸으로 제목 줄을 맞춤
            Button { store.setCollapsed(item, !item.isCollapsed) } label: {
                Text(isStory ? (item.isCollapsed ? "▸" : "▾") : " ")
                    .font(.term(16, .bold))
                    .foregroundStyle(Color.term.dim)
                    .frame(width: 14, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isStory)
            .padding(.trailing, -6)
            .accessibilityLabel(item.isCollapsed ? "\(item.title) 펼치기" : "\(item.title) 접기")
            .accessibilityHidden(!isStory)

            if store.renamingID == item.id {
                HStack(spacing: 0) {
                    if row.depth == 1 {
                        Text(row.isLastChild ? "└ " : "├ ").foregroundStyle(Color.term.muted)
                    }
                    RenameField(item: item)
                }
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            } else {
                Button { store.select(item) } label: {
                    HStack(spacing: 0) {
                        if row.depth == 1 {
                            Text(row.isLastChild ? "└ " : "├ ").foregroundStyle(Color.term.muted)
                        }
                        Text(item.title)
                            .strikethrough(item.isDone, color: Color.term.muted)
                            .foregroundStyle(item.isDone ? Color.term.muted : isActive ? Color.white : Color.term.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let p = store.taskProgress(item) {
                            Text(" [\(p.done)/\(p.total)]")
                                .font(.term(12))
                                .foregroundStyle(p.done == p.total ? Color.term.accentFocus : Color.term.muted)
                        }
                        if isActive {
                            Text("  ◀ now").font(.term(14, .bold)).foregroundStyle(Color.term.accentFocus)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // 더블클릭하면 그 자리에서 제목 수정 (첫 클릭은 집중 대상 선택)
                .simultaneousGesture(TapGesture(count: 2).onEnded { store.beginRename(item) })
                .accessibilityLabel("\(item.title) 집중하기")
                .accessibilityAction(named: "제목 수정") { store.beginRename(item) }
            }

            // 마우스를 올리면 나타나는 버튼. 자리는 항상 차지해서 칸이 흔들리지 않게 함
            let showActions = hovering || TaskRowDebug.alwaysShowActions
            HStack(spacing: 6) {
                if row.depth == 0 && !item.isDone {
                    RowActionButton(title: "+ sub", label: "\(item.title)에 하위 태스크 추가") {
                        store.beginAdd(.sub(item.id))
                    }
                }
                Menu { menu } label: {
                    Text("⋯")
                        .font(.term(13, .bold))
                        .foregroundStyle(Color.term.text)
                        .frame(width: 28, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.term.borderStrong))
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("\(item.title) 메뉴")
            }
            .opacity(showActions ? 1 : 0)
            .allowsHitTesting(showActions)
            .accessibilityHidden(!showActions)

            if showsPeriod {
                period.frame(width: Self.periodWidth, alignment: .leading)
            }

            if let m = item.focusMinutes {
                Text("\(m)m")
                    .font(.term(12))
                    .foregroundStyle(Color.term.muted)
                    .accessibilityLabel("집중 \(m)분")
            }
            Text("#\(item.project.rawValue)")
                .font(.term(13))
                .foregroundStyle(item.project.color)
            Text(store.pomoBar(for: item))
                .font(.term(13))
                .tracking(1)
                .foregroundStyle(Color.term.error)
                .frame(minWidth: 52, alignment: .leading)
        }
        .frame(minHeight: 44)
        .background(isActive ? Color.term.activeRow : Color.clear)
        .overlay(alignment: .bottom) { DashedLine(color: .term.borderDashed) }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
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
        Button(item.isDone ? "미완료로 되돌리기" : "완료", action: toggleDone)
        Button("제목 수정") { store.beginRename(item) }
        Divider()
        if row.depth == 0 && !item.isDone {
            Button("하위 태스크 추가…") { store.beginAdd(.sub(item.id)) }
        }
        if isStory {
            Button(item.isCollapsed ? "펼치기" : "접기") { store.setCollapsed(item, !item.isCollapsed) }
        }
        Divider()
        Button(item.isScheduled ? "기간 변경…" : "기간 설정…", action: onEditPeriod)
        if item.isScheduled { Button("기간 해제 (오늘 할 일로)") { store.setPeriod(item, start: nil, due: nil) } }
        Picker("태그", selection: Binding(get: { item.project },
                                         set: { p in store.setProject(item, p) })) {
            ForEach(Project.allCases, id: \.self) { Text("#\($0.rawValue)").tag($0) }
        }
        Picker("집중 시간", selection: Binding(get: { item.focusMinutes },
                                           set: { m in store.setFocusMinutes(item, m) })) {
            Text("기본 (\(store.settings.focusMinutes)분)").tag(Int?.none)
            Divider()
            ForEach([15, 25, 30, 45, 50, 60, 90], id: \.self) { Text("\($0)분").tag(Int?.some($0)) }
            if let m = item.focusMinutes, ![15, 25, 30, 45, 50, 60, 90].contains(m) {
                Text("\(m)분").tag(Int?.some(m))
            }
        }
        Picker("예상 뽀모도로", selection: Binding(get: { item.estimatedPomodoros },
                                             set: { n in store.update(item) { $0.estimatedPomodoros = n } })) {
            ForEach(1...8, id: \.self) { Text("\($0)").tag($0) }
        }
        Divider()
        let kids = store.children(of: item).count
        Button(kids > 0 ? "삭제 (태스크 \(kids)개 포함)" : "삭제", role: .destructive) { store.delete(item) }
    }

    /// 열린 태스크가 있는 스토리를 완료할 때는 태스크도 함께 완료할지 물어봄
    private func toggleDone() {
        if !item.isDone && store.openChildrenCount(item) > 0 {
            confirmingDone = true
        } else {
            store.toggleDone(item)
        }
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
                HStack(spacing: 6) {
                    Text("$ pomo \(store.mode.key) --running=\(store.isRunning ? "true" : "false")")
                        .font(.term(13))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    let step = AppStore.minuteStep(for: store.mode)
                    MinuteButton(title: "−\(step)", label: "\(store.mode.key) \(step)분 줄이기") { store.adjustCurrentMinutes(by: -1) }
                    MinuteButton(title: "+\(step)", label: "\(store.mode.key) \(step)분 늘리기") { store.adjustCurrentMinutes(by: 1) }
                }
                .disabled(store.isRunning)
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
                infoLine("task  ", store.selectedTodo.map { t in
                    (store.parent(of: t).map { "\($0.title) › " } ?? "") + t.title + (t.focusMinutes.map { "  [\($0)m]" } ?? "")
                } ?? "(none) — focus <#> 로 선택")
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
                Text("sub <#> <태스크> · mv <#> <제목>   (#: 1, 1.2)")
                Text("ls today|sched · due <#> <M/D~M/D> (해제 -)")
                Text("mode <m> · set <m> <분> · time <#> <분>")
                Text("mini · clear · help   (m: focus|short|long)")
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

/// 제목을 그 자리에서 고치는 입력칸. Enter나 다른 곳을 누르면 저장, Esc는 취소
private struct RenameField: View {
    @EnvironmentObject var store: AppStore
    let item: TodoItem
    @State private var text: String
    @FocusState private var focused: Bool

    init(item: TodoItem) {
        self.item = item
        _text = State(initialValue: item.title)
    }

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 4)
            .frame(height: 28)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.term.accentFocus))
            .focused($focused)
            .onSubmit(save)
            .onExitCommand { store.renamingID = nil }
            .onAppear { DispatchQueue.main.async { focused = true } }
            .onChange(of: focused) { isFocused in
                if !isFocused && store.renamingID == item.id { save() }
            }
            .accessibilityLabel("\(item.title) 제목 수정")
    }

    private func save() {
        store.rename(item, text)
        store.renamingID = nil
    }
}

/// 스냅샷에서 마우스 오버 버튼을 확인하기 위한 스위치
enum TaskRowDebug {
    static var alwaysShowActions = false
}

/// 행에 마우스를 올리면 나타나는 작은 버튼
private struct RowActionButton: View {
    let title: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.term(12, .bold))
                .foregroundStyle(Color.term.accentFocus)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.term.borderStrong))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(label)
    }
}

/// 집중·휴식 시간 −/+ 버튼. 실행 중엔 비활성
private struct MinuteButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.term(12, .bold))
                .foregroundStyle(isEnabled ? Color.term.text : Color.term.muted)
                .frame(width: 40, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(isEnabled ? Color.term.borderStrong : Color.term.border))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Command line & status bar

private struct CommandLineBar: View {
    @EnvironmentObject var store: AppStore
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("❯").font(.term(15, .extraBold)).foregroundStyle(Color.term.accentFocus)
            TextField("", text: $store.commandDraft,
                      prompt: Text("명령어 입력 (예: add 리팩터링, done 2, start)").foregroundColor(Color.term.muted))
                .textFieldStyle(.plain)
                .font(.term(14))
                .foregroundStyle(Color.term.bright)
                .focused($focused)
                .onSubmit {
                    store.run(command: store.commandDraft)
                    store.commandDraft = ""
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
            cell("\(store.todayBreakCount) break · \(AppStore.durationText(store.todayBreakMinutes))", fg: .term.accentBreak, weight: .medium)
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
