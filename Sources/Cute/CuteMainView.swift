import SwiftUI

/// 귀여운 테마 메인 창 (reference/CuteMain.dc.html): 사이드바 · 할 일 · 타이머 패널
struct CuteMainView: View {
    @EnvironmentObject var store: AppStore
    @State private var projectFilter: Project?
    @State private var editingPeriod: TodoItem?

    private static let sidebarWidth: CGFloat = 230
    private static let timerWidth: CGFloat = 350

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                CuteSidebar(projectFilter: $projectFilter)
                    .frame(width: Self.sidebarWidth)
                // 좁아지면 타이머 패널을 할 일 아래로
                if geo.size.width >= Self.sidebarWidth + 440 + Self.timerWidth {
                    CuteTaskColumn(projectFilter: $projectFilter, scrolls: true) { editingPeriod = $0 }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    CuteTimerPanel()
                        .frame(width: Self.timerWidth)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            CuteTaskColumn(projectFilter: $projectFilter, scrolls: false) { editingPeriod = $0 }
                            CuteTimerPanel()
                        }
                    }
                }
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.cute.ink)
        .background(Color.cute.window)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .frame(minWidth: 700, minHeight: 640)
        .sheet(item: $editingPeriod) { item in
            PeriodEditor(item: item).environmentObject(store).environment(\.themeID, .cute)
        }
    }
}

// MARK: - Sidebar

private struct CuteSidebar: View {
    @EnvironmentObject var store: AppStore
    @Binding var projectFilter: Project?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // 시스템 신호등 버튼 자리
            Color.clear.frame(height: 14)

            HStack(spacing: 10) {
                TomatoMascot(mood: .idle, size: 40, lineScale: 2, simple: true)
                Text("토마토 타임").font(.system(size: 22, weight: .semibold))
            }
            .padding(.horizontal, 6)

            VStack(spacing: 4) {
                navItem(.today, "오늘", icon: .sun)
                navItem(.scheduled, "예정", icon: .calendar)
                navItem(.done, "완료함", icon: .check)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("프로젝트")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cute.inkSecondary)
                    .padding(.horizontal, 12)
                ForEach(Project.allCases, id: \.self) { projectItem($0) }
            }

            Spacer(minLength: 0)
            TodayTomatoCard()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.cute.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.cute.sidebarDivider).frame(width: 2) }
    }

    private func navItem(_ tab: ListTab, _ title: String, icon: CuteNavIcon.Kind) -> some View {
        let selected = store.listTab == tab
        let count = store.openLeafCount(tab)
        return Button { store.listTab = tab } label: {
            HStack(spacing: 10) {
                CuteNavIcon(kind: icon)
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 0)
                if selected {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                        .frame(minWidth: 24, minHeight: 24)
                        .cuteSurface(Capsule(style: .circular), fill: .white)
                } else {
                    Text("\(count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.cute.inkSecondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .circular).fill(Color.cute.peach)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .circular).strokeBorder(Color.cute.ink, lineWidth: 2))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(tab.shortcutKey, modifiers: .command)
        .accessibilityLabel("\(tab.accessibilityName) \(count)개")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func projectItem(_ project: Project) -> some View {
        let selected = projectFilter == project
        let count = store.todos.filter { !$0.isDone && $0.project == project && !store.hasChildren($0) }.count
        return Button { projectFilter = selected ? nil : project } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .circular)
                    .fill(project.cuteChip)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .circular).strokeBorder(Color.cute.ink, lineWidth: 2))
                    .frame(width: 22, height: 22)
                Text(project.rawValue).font(.system(size: 15, weight: selected ? .semibold : .regular))
                Spacer(minLength: 0)
                Text("\(count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.cute.inkSecondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .circular).fill(Color.cute.peach)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .circular).strokeBorder(Color.cute.ink, lineWidth: 2))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? "\(project.rawValue)만 보는 중, 누르면 해제" : "\(project.rawValue)만 보기")
    }
}

/// 사이드바 아이콘 (시안의 SVG를 옮김, 24×24 좌표)
private struct CuteNavIcon: View {
    enum Kind { case sun, calendar, check }
    let kind: Kind

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            let ink = GraphicsContext.Shading.color(.cute.ink)
            let style = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            switch kind {
            case .sun:
                let c = Path(ellipseIn: CGRect(x: 7.5, y: 7.5, width: 9, height: 9))
                ctx.fill(c, with: .color(.cute.butter))
                ctx.stroke(c, with: ink, style: style)
                ctx.stroke(Path { p in
                    for (a, b) in [((12, 2), (12, 4)), ((12, 20), (12, 22)), ((4.9, 4.9), (6.3, 6.3)), ((17.7, 17.7), (19.1, 19.1)),
                                   ((2, 12), (4, 12)), ((20, 12), (22, 12)), ((4.9, 19.1), (6.3, 17.7)), ((17.7, 6.3), (19.1, 4.9))] {
                        p.move(to: CGPoint(x: a.0, y: a.1)); p.addLine(to: CGPoint(x: b.0, y: b.1))
                    }
                }, with: ink, style: style)
            case .calendar:
                let r = Path(roundedRect: CGRect(x: 3, y: 5, width: 18, height: 16), cornerRadius: 4)
                ctx.fill(r, with: .color(.cute.sky))
                ctx.stroke(r, with: ink, style: style)
                ctx.stroke(Path { p in
                    p.move(to: .init(x: 16, y: 3)); p.addLine(to: .init(x: 16, y: 7))
                    p.move(to: .init(x: 8, y: 3)); p.addLine(to: .init(x: 8, y: 7))
                    p.move(to: .init(x: 3, y: 11)); p.addLine(to: .init(x: 21, y: 11))
                }, with: ink, style: style)
            case .check:
                let c = Path(ellipseIn: CGRect(x: 3, y: 3, width: 18, height: 18))
                ctx.fill(c, with: .color(.cute.sage))
                ctx.stroke(c, with: ink, style: style)
                ctx.stroke(Path { p in
                    p.move(to: .init(x: 8, y: 12.5)); p.addLine(to: .init(x: 11, y: 15.5)); p.addLine(to: .init(x: 16, y: 9.5))
                }, with: ink, style: style)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

/// "오늘 딴 토마토" 카드: 오늘 완료한 뽀모도로·집중 시간·휴식
private struct TodayTomatoCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘 딴 토마토").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.cute.inkSecondary)
            if store.todayCount > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<min(store.todayCount, 8), id: \.self) { _ in TomatoIcon(style: .filled, size: 22) }
                    if store.todayCount > 8 {
                        Text("+\(store.todayCount - 8)").font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            Text(store.todayCount > 0 ? "\(store.todayCount)개 · \(cuteDuration(store.todayFocusMinutes)) 집중했어요"
                                      : "아직 딴 토마토가 없어요")
                .font(.system(size: 13))
            Text("휴식 \(store.todayBreakCount)번 · \(cuteDuration(store.todayBreakMinutes))")
                .font(.system(size: 13))
                .foregroundStyle(Color.cute.inkSecondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteSurface(radius: 18, fill: .white, shadow: 4)
        .accessibilityElement(children: .combine)
    }
}

/// 75 → "1시간 15분"
func cuteDuration(_ minutes: Int) -> String {
    if minutes >= 60 { return minutes % 60 == 0 ? "\(minutes / 60)시간" : "\(minutes / 60)시간 \(minutes % 60)분" }
    return "\(minutes)분"
}

// MARK: - 할 일 칼럼

private struct CuteTaskColumn: View {
    @EnvironmentObject var store: AppStore
    @Binding var projectFilter: Project?
    let scrolls: Bool
    let onEditPeriod: (TodoItem) -> Void

    /// 프로젝트 필터는 스토리 기준이고 하위 태스크는 스토리를 따라감
    private var rows: [ListRow] {
        let all = store.rows(store.listTab)
        guard let projectFilter else { return all }
        let storyIDs = Set(all.filter { $0.depth == 0 && $0.item.project == projectFilter }.map(\.item.id))
        return all.filter { storyIDs.contains($0.depth == 0 ? $0.item.id : ($0.item.parentID ?? $0.item.id)) }
    }

    var body: some View {
        let rows = rows
        VStack(alignment: .leading, spacing: 20) {
            header(rows)
            if store.listTab != .done {
                CuteAddBar { added in if store.listTab == .scheduled { onEditPeriod(added) } }
            }
            if scrolls {
                ScrollView { list(rows).padding(.bottom, 8) }
            } else {
                list(rows)
            }
        }
        .padding(.top, 30)
        .padding(.horizontal, 32)
        .padding(.bottom, scrolls ? 0 : 32)
    }

    private var title: String {
        switch store.listTab {
        case .today: return "오늘의 할 일"
        case .scheduled: return "예정된 할 일"
        case .done: return "완료함"
        }
    }

    private var subtitle: String {
        switch store.listTab {
        case .today:
            let f = DateFormatter()
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = "M월 d일 EEEE"
            return "\(f.string(from: Date())) · 오늘도 한 알씩 키워봐요"
        case .scheduled: return "기간을 정해둔 할 일 · 마감이 가까운 순서예요"
        case .done: return "다 키운 토마토들이에요"
        }
    }

    private func header(_ rows: [ListRow]) -> some View {
        let leaves = rows.filter { !store.hasChildren($0.item) }
        let doneCount = leaves.filter(\.item.isDone).count
        let remaining = leaves.filter { !$0.item.isDone }
            .reduce(0) { $0 + max(0, $1.item.estimatedPomodoros - $1.item.completedPomodoros) }
        return HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 30, weight: .bold)).tracking(-0.3)
                HStack(spacing: 8) {
                    Text(subtitle).font(.system(size: 14)).foregroundStyle(Color.cute.inkSecondary)
                    if let projectFilter {
                        Button { self.projectFilter = nil } label: {
                            HStack(spacing: 4) {
                                Text("\(projectFilter.rawValue)만 보는 중")
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 10)
                            .background(projectFilter.cuteChip, in: Capsule(style: .circular))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(projectFilter.rawValue) 필터 해제")
                    }
                }
            }
            Spacer(minLength: 0)
            if store.listTab != .done && !leaves.isEmpty {
                VStack(alignment: .trailing, spacing: 6) {
                    (Text("\(leaves.count)개 중 ") + Text("\(doneCount)").bold() + Text("개 끝! · 토마토 \(remaining)개 남음"))
                        .font(.system(size: 13))
                    CuteProgressBar(fraction: Double(doneCount) / Double(leaves.count)).frame(width: 200)
                }
            }
        }
    }

    @ViewBuilder
    private func list(_ rows: [ListRow]) -> some View {
        if store.listTab == .done {
            let stories = rows.filter { $0.depth == 0 }
            VStack(alignment: .leading, spacing: 4) {
                if stories.isEmpty { emptyCard("아직 다 키운 토마토가 없어요") }
                ForEach(stories) { CuteDoneRow(row: $0, showsDate: true, onEditPeriod: onEditPeriod) }
            }
        } else {
            let open = rows.filter { $0.depth == 0 && !$0.item.isDone }
            let done = rows.filter { $0.depth == 0 && $0.item.isDone }
            VStack(alignment: .leading, spacing: 10) {
                if open.isEmpty {
                    emptyCard(store.listTab == .today ? "오늘 할 일이 없어요. 위에 하나 적어볼까요?"
                                                      : "기간을 정한 할 일이 없어요")
                }
                ForEach(open) { story in
                    CuteStoryGroup(story: story, tasks: rows.filter { $0.item.parentID == story.item.id },
                                   onEditPeriod: onEditPeriod)
                }
                if !done.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("다 했어요 · \(done.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.cute.inkSecondary)
                            .padding(.top, 6)
                            .padding(.horizontal, 4)
                        ForEach(done) { CuteDoneRow(row: $0, showsDate: false, onEditPeriod: onEditPeriod) }
                    }
                }
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            TomatoMascot(mood: .idle, size: 44, lineScale: 2, simple: true)
            Text(text).font(.system(size: 14)).foregroundStyle(Color.cute.inkSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteSurface(radius: 18, fill: .white, border: .cute.rowBorder)
    }
}

/// 맨 위 입력줄: "새로운 할 일을 적고 Enter!" + 추가 버튼. ⌘N으로 포커스
private struct CuteAddBar: View {
    @EnvironmentObject var store: AppStore
    let onAdded: (TodoItem) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.cute.link)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.cute.placeholder))
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($focused)
                .onSubmit(submit)
                .frame(height: 38)
                .accessibilityLabel("새 할 일")
            Button(action: submit) {
                Text("추가").font(.system(size: 15, weight: .semibold)).padding(.horizontal, 18).frame(height: 38)
            }
            .buttonStyle(CuteButtonStyle(fill: .cute.butter, radius: 12))
        }
        .padding(.vertical, 5)
        .padding(.leading, 14)
        .padding(.trailing, 5)
        .cuteSurface(radius: 16, fill: .white)
        .onChange(of: store.inlineAdd) { target in
            // ⌘N: 맨 위 입력줄로
            if target == .top {
                focused = true
                store.inlineAdd = nil
            }
        }
    }

    private var placeholder: String {
        store.listTab == .scheduled ? "기간 할 일을 적고 Enter! (추가 후 기간 설정)" : "새로운 할 일을 적고 Enter!"
    }

    private func submit() {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if let item = store.submitInlineAdd(.top, title) { onAdded(item) }
        text = ""
        focused = true
    }
}

// MARK: - 할 일 카드

/// 스토리 카드와 그 아래 들여 쓴 태스크 카드들
private struct CuteStoryGroup: View {
    @EnvironmentObject var store: AppStore
    let story: ListRow
    let tasks: [ListRow]
    let onEditPeriod: (TodoItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CuteTaskCard(row: story, onEditPeriod: onEditPeriod)
            if !story.item.isCollapsed {
                ForEach(tasks) { task in
                    if task.item.isDone {
                        CuteDoneRow(row: task, showsDate: false, onEditPeriod: onEditPeriod).padding(.leading, 40)
                    } else {
                        CuteTaskCard(row: task, onEditPeriod: onEditPeriod).padding(.leading, 40)
                    }
                }
            }
            if store.inlineAdd == .sub(story.item.id) {
                CuteSubAddRow(storyID: story.item.id).padding(.leading, 40)
            }
        }
    }
}

private struct CuteTaskCard: View {
    @EnvironmentObject var store: AppStore
    let row: ListRow
    let onEditPeriod: (TodoItem) -> Void
    @State private var confirmingDone = false
    @State private var hovering = false

    private var item: TodoItem { row.item }
    private var isTask: Bool { row.depth == 1 }
    private var isActive: Bool { store.selectedTodo?.id == item.id }
    private var isStory: Bool { row.depth == 0 && store.hasChildren(item) }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.requestToggleDone(item, confirm: $confirmingDone) } label: {
                CuteCheckbox(done: item.isDone, size: isTask ? 20 : 24).frame(width: 44, height: isTask ? 36 : 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "\(item.title) 완료 취소" : "\(item.title) 완료로 표시")
            .storyCompletionDialog(item, isPresented: $confirmingDone, store: store)
            .padding(.trailing, -6)

            VStack(alignment: .leading, spacing: isTask ? 4 : 6) {
                HStack(spacing: 6) {
                    if isStory {
                        Button { store.setCollapsed(item, !item.isCollapsed) } label: {
                            Image(systemName: item.isCollapsed ? "chevron.right" : "chevron.down")
                                .font(.system(size: 11, weight: .heavy))
                                .frame(width: 16, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.isCollapsed ? "\(item.title) 펼치기" : "\(item.title) 접기")
                    }
                    if store.renamingID == item.id {
                        RenameField(item: item)
                            .font(.system(size: isTask ? 14 : 15))
                            .padding(.horizontal, 6)
                            .frame(height: 26)
                            .cuteSurface(radius: 8, fill: .white)
                    } else {
                        Text(item.title)
                            .font(.system(size: isTask ? 14 : 15))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .onTapGesture(count: 2) { store.beginRename(item) }
                            .accessibilityAction(named: "제목 수정") { store.beginRename(item) }
                    }
                }
                metaLine
            }

            Spacer(minLength: 8)

            // 마우스를 올리면 나타나는 버튼 (카드라서 자리를 미리 비워두지 않음)
            if hovering || TaskRowDebug.alwaysShowActions {
                HStack(spacing: 6) {
                    if row.depth == 0 {
                        Button { store.beginAdd(.sub(item.id)) } label: {
                            Text("+ 태스크").font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).frame(height: 28)
                        }
                        .buttonStyle(CuteButtonStyle(fill: .white, radius: 10, shadow: 2))
                        .fixedSize()
                        .accessibilityLabel("\(item.title)에 하위 태스크 추가")
                    }
                    Menu { menu } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.cute.ink)
                            .frame(width: 28, height: 28)
                            .cuteSurface(Circle(), fill: .white)
                            .contentShape(Circle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("\(item.title) 메뉴")
                }
            }

            Button { store.select(item) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 10))
                    Text(isActive ? "키우는 중" : "집중하기").font(.system(size: isTask ? 13 : 14, weight: .semibold))
                }
                .padding(.horizontal, isTask ? 12 : 14)
                .frame(height: isTask ? 32 : 38)
            }
            .buttonStyle(CuteButtonStyle(fill: isActive ? .cute.peach : .white, radius: isTask ? 16 : 19, shadow: isActive ? 0 : 3))
            .fixedSize()
            .accessibilityLabel("\(item.title) 집중하기")
            .accessibilityAddTraits(isActive ? .isSelected : [])
        }
        .padding(.vertical, isTask ? 4 : 8)
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .cuteSurface(radius: isTask ? 14 : 18, fill: isActive ? .cute.rowActiveBg : .white,
                     border: isActive ? .cute.ink : .cute.rowBorder, shadow: isActive ? 4 : 0)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu { menu }
    }

    private var menu: some View {
        TaskMenuItems(item: item, depth: row.depth,
                      onToggleDone: { store.requestToggleDone(item, confirm: $confirmingDone) },
                      onEditPeriod: { onEditPeriod(item) })
    }

    /// 칩 · 기간 · 집중 시간 · 토마토 아이콘 · 1/3
    private var metaLine: some View {
        let counts = store.pomoCounts(item)
        let n = max(counts.est, counts.done)
        return HStack(spacing: 8) {
            // 태스크는 스토리와 태그가 같으면 칩을 생략
            if !isTask || item.project != store.parent(of: item)?.project {
                ProjectChip(project: item.project, fontSize: isTask ? 11 : 12)
            }
            if let due = item.dueDate { PeriodChip(start: item.startDate, due: due) }
            if let m = item.focusMinutes {
                HStack(spacing: 3) {
                    Image(systemName: "timer").font(.system(size: 10, weight: .semibold))
                    Text("\(m)분")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(Color.cute.sidebar, in: Capsule(style: .circular))
                .accessibilityLabel("집중 \(m)분")
            }
            HStack(spacing: 2) {
                ForEach(0..<min(n, 6), id: \.self) { i in
                    TomatoIcon(style: i < counts.done ? .filled : .empty, size: isTask ? 14 : 16)
                }
                if n > 6 { Text("+\(n - 6)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.cute.inkSecondary) }
            }
            Text("\(counts.done)/\(counts.est)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.cute.inkSecondary)
                .fixedSize()
                .accessibilityLabel("토마토 \(counts.est)개 중 \(counts.done)개")
            if let p = store.taskProgress(item) {
                Text("태스크 \(p.done)/\(p.total)")
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize()
                    .foregroundStyle(p.done == p.total ? Color(hex: 0x3FA67E) : Color.cute.inkSecondary)
            }
        }
    }
}

/// 기간 칩: 마감이 지났거나 오늘이면 peach, 3일 이내면 butter
private struct PeriodChip: View {
    let start: Date?
    let due: Date

    var body: some View {
        let days = Period.daysLeft(until: due)
        let bg: Color = days <= 0 ? .cute.peach : days <= 3 ? Color(hex: 0xFFE8A8) : .cute.sidebar
        Text("\(Period.text(start: start, due: due)) · \(Period.ddayText(until: due))")
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(days <= 0 ? Color.cute.link : Color.cute.ink)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(bg, in: Capsule(style: .circular))
            .accessibilityLabel("기간 \(Period.text(start: start, due: due)), \(Period.ddayText(until: due))")
    }
}

private struct CuteCheckbox: View {
    let done: Bool
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size / 3, style: .circular).fill(done ? Color.cute.leaf : Color.white)
            RoundedRectangle(cornerRadius: size / 3, style: .circular).strokeBorder(Color.cute.ink, lineWidth: 2)
            if done {
                Path { p in
                    p.move(to: CGPoint(x: 5, y: 12.5)); p.addLine(to: CGPoint(x: 9.5, y: 17)); p.addLine(to: CGPoint(x: 19, y: 7.5))
                }
                .applying(CGAffineTransform(scaleX: size * 0.58 / 24, y: size * 0.58 / 24))
                .stroke(Color.cute.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.58, height: size * 0.58)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 완료한 할 일: 초록 체크 + 취소선 제목
private struct CuteDoneRow: View {
    @EnvironmentObject var store: AppStore
    let row: ListRow
    let showsDate: Bool
    let onEditPeriod: (TodoItem) -> Void
    @State private var confirmingDone = false

    private var item: TodoItem { row.item }

    var body: some View {
        let counts = store.pomoCounts(item)
        HStack(spacing: 10) {
            Button { store.toggleDone(item) } label: {
                CuteCheckbox(done: true, size: row.depth == 1 ? 20 : 24).frame(width: 44, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.title) 완료 취소")
            .padding(.trailing, -6)

            Text(item.title)
                .font(.system(size: row.depth == 1 ? 14 : 15))
                .foregroundStyle(Color.cute.inkSecondary)
                .strikethrough(true, color: Color.cute.inkSecondary)
                .lineLimit(1)
            if let p = store.taskProgress(item) {
                Text("태스크 \(p.total)개").font(.system(size: 12)).foregroundStyle(Color.cute.inkSecondary)
            }
            Spacer(minLength: 8)
            if showsDate, let at = item.completedAt {
                Text(Self.dateFormatter.string(from: at)).font(.system(size: 12)).foregroundStyle(Color.cute.inkSecondary)
            }
            Text("\(counts.done)/\(counts.est)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.cute.inkSecondary)
        }
        .padding(.vertical, 2)
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .contentShape(Rectangle())
        .contextMenu {
            TaskMenuItems(item: item, depth: row.depth, onToggleDone: { store.toggleDone(item) },
                          onEditPeriod: { onEditPeriod(item) })
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f
    }()
}

/// 스토리 아래 태스크 입력 카드. Enter로 추가하고 남아 있음, Esc나 빈 채로 포커스를 잃으면 닫힘
private struct CuteSubAddRow: View {
    @EnvironmentObject var store: AppStore
    let storyID: UUID
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color.cute.link)
            TextField("", text: $text, prompt: Text("태스크 이름을 적고 Enter!").foregroundColor(Color.cute.placeholder))
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($focused)
                .onSubmit(submit)
                .onExitCommand(perform: close)
                .onAppear { DispatchQueue.main.async { focused = true } }
                .onChange(of: focused) { isFocused in
                    if !isFocused && text.trimmingCharacters(in: .whitespaces).isEmpty { close() }
                }
                .accessibilityLabel("태스크 추가")
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .cuteSurface(radius: 14, fill: .white)
    }

    private func submit() {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { close(); return }
        store.submitInlineAdd(.sub(storyID), title)
        text = ""
        focused = true
    }

    private func close() {
        text = ""
        if store.inlineAdd == .sub(storyID) { store.inlineAdd = nil }
    }
}
