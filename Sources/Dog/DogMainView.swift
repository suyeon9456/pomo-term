import SwiftUI

/// 강아지 테마 메인 창 (PomPhotoMain / GoldenPhotoMain): 사이드바 · 할 일 · 타이머 패널
struct DogMainView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.themeID) private var themeID
    let style: DogStyle
    @State private var projectFilter: Project?
    @State private var editingPeriod: TodoItem?

    private static let sidebarWidth: CGFloat = 230

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                DogSidebar(style: style, projectFilter: $projectFilter)
                    .frame(width: Self.sidebarWidth)
                // 좁아지면 타이머 패널을 할 일 아래로
                if geo.size.width >= Self.sidebarWidth + 440 + style.panelWidth {
                    DogTaskColumn(style: style, projectFilter: $projectFilter, scrolls: true) { editingPeriod = $0 }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    DogTimerPanel(style: style)
                        .frame(width: style.panelWidth)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            DogTaskColumn(style: style, projectFilter: $projectFilter, scrolls: false) { editingPeriod = $0 }
                            DogTimerPanel(style: style).frame(height: 900)
                        }
                    }
                }
            }
        }
        .font(.system(size: 15, design: .rounded))
        .fontDesign(.rounded)
        .foregroundStyle(style.text)
        .background(style.window)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .frame(minWidth: 700, minHeight: 700)
        .sheet(item: $editingPeriod) { item in
            PeriodEditor(item: item).environmentObject(store).environment(\.themeID, themeID)
        }
    }
}

// MARK: - Sidebar

private struct DogSidebar: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
    @Binding var projectFilter: Project?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // 시스템 신호등 버튼 자리
            Color.clear.frame(height: 14)

            HStack(spacing: 10) {
                DogAvatar(file: style.avatarHappy, size: 42, background: style.sidebar)
                Text(style.appName).font(.system(size: 20, weight: .bold, design: .rounded)).tracking(-0.2)
            }
            .padding(.horizontal, 6)

            VStack(spacing: 4) {
                navItem(.today, "오늘", icon: style.todayIcon)
                navItem(.scheduled, "예정", icon: .calendar)
                navItem(.done, style.doneTitle, icon: style.doneIcon)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("프로젝트")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(style.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                ForEach(Project.allCases, id: \.self) { projectItem($0) }
            }

            Spacer(minLength: 0)
            todayCard
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(style.sidebar)
    }

    private func navItem(_ tab: ListTab, _ title: String, icon: DogNavIcon.Kind) -> some View {
        let selected = store.listTab == tab
        let count = store.openLeafCount(tab)
        // 오늘 아이콘은 테마 색, 나머지는 보조 색
        let iconColor = icon == style.todayIcon && tab == .today ? style.focusAccent : style.textSecondary
        return Button { store.listTab = tab } label: {
            HStack(spacing: 10) {
                DogNavIcon(kind: icon, color: iconColor)
                Text(title).font(.system(size: 15, weight: selected ? .bold : .medium, design: .rounded))
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: 13, weight: selected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(selected ? style.strong : style.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                if selected { Color.clear.dogCard(style, radius: style.cardRadius - 4, shadow: 0.10) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(tab.shortcutKey, modifiers: .command)
        .accessibilityLabel("\(title) \(count)개")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func projectItem(_ project: Project) -> some View {
        let selected = projectFilter == project
        let count = store.todos.filter { !$0.isDone && $0.project == project && !store.hasChildren($0) }.count
        return Button { projectFilter = selected ? nil : project } label: {
            HStack(spacing: 10) {
                Circle().fill(style.dot(project)).frame(width: 12, height: 12)
                Text(project.rawValue).font(.system(size: 15, weight: selected ? .bold : .regular, design: .rounded))
                Spacer(minLength: 0)
                Text("\(count)").font(.system(size: 13, design: .rounded)).foregroundStyle(style.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                if selected { Color.clear.dogCard(style, radius: style.cardRadius - 4, shadow: 0.10) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? "\(project.rawValue)만 보는 중, 누르면 해제" : "\(project.rawValue)만 보기")
    }

    /// "오늘 받은 간식" / "오늘 물어온 공"
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(style.todayCardTitle).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(style.textSecondary)
            if store.todayCount > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<min(store.todayCount, 7), id: \.self) { _ in
                        TreatIcon(treat: style.treat, filled: true, size: style.treat == .bone ? 26 : 22)
                    }
                    if store.todayCount > 7 {
                        Text("+\(store.todayCount - 7)").font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
            }
            Text(store.todayCount > 0 ? "\(store.todayCount)개 · \(cuteDuration(store.todayFocusMinutes)) \(style.todayCardSuffix)"
                                      : "아직 \(style.treatNoun)이 없어요")
                .font(.system(size: 13, design: .rounded))
            Text("휴식 \(store.todayBreakCount)번 · \(cuteDuration(store.todayBreakMinutes))")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(style.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dogCard(style, radius: style.cardRadius + 2, shadow: 0.10, shadowRadius: 16, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 할 일 칼럼

private struct DogTaskColumn: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
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
                DogAddBar(style: style) { added in if store.listTab == .scheduled { onEditPeriod(added) } }
            }
            if scrolls {
                // 카드 그림자가 잘리지 않게 안쪽 여백
                ScrollView { list(rows).padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 12) }.padding(.horizontal, -4)
            } else {
                list(rows)
            }
        }
        .padding(.top, 32)
        .padding(.horizontal, 32)
        .padding(.bottom, scrolls ? 0 : 32)
    }

    private var title: String {
        switch store.listTab {
        case .today: return "오늘의 할 일"
        case .scheduled: return "예정된 할 일"
        case .done: return style.doneTitle
        }
    }

    private var subtitle: String {
        switch store.listTab {
        case .today:
            let f = DateFormatter()
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = "M월 d일 EEEE"
            return "\(f.string(from: Date())) · \(style.subtitle)"
        case .scheduled: return "기간을 정해둔 할 일 · 마감이 가까운 순서예요"
        case .done: return "그동안 함께 해낸 일이에요"
        }
    }

    private func header(_ rows: [ListRow]) -> some View {
        let leaves = rows.filter { !store.hasChildren($0.item) }
        let doneCount = leaves.filter(\.item.isDone).count
        let remaining = leaves.filter { !$0.item.isDone }
            .reduce(0) { $0 + max(0, $1.item.estimatedPomodoros - $1.item.completedPomodoros) }
        return HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 30, weight: .bold, design: .rounded)).tracking(-0.3)
                HStack(spacing: 8) {
                    Text(subtitle).font(.system(size: 14, design: .rounded)).foregroundStyle(style.textSecondary)
                    if let projectFilter {
                        Button { self.projectFilter = nil } label: {
                            HStack(spacing: 4) {
                                Text("\(projectFilter.rawValue)만 보는 중")
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 10)
                            .background(style.chip(projectFilter), in: Capsule(style: .circular))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(projectFilter.rawValue) 필터 해제")
                    }
                }
            }
            Spacer(minLength: 0)
            if store.listTab != .done && !leaves.isEmpty {
                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(leaves.count)개 중 \(doneCount)개 \(style.doneVerb) · \(style.treatNoun) \(remaining)개 남음")
                        .font(.system(size: 13, design: .rounded))
                    DogProgressBar(fraction: Double(doneCount) / Double(leaves.count), fill: style.focusAccent, track: style.track)
                        .frame(width: 200)
                }
            }
        }
    }

    @ViewBuilder
    private func list(_ rows: [ListRow]) -> some View {
        if store.listTab == .done {
            let stories = rows.filter { $0.depth == 0 }
            VStack(alignment: .leading, spacing: 2) {
                if stories.isEmpty { emptyCard("아직 \(style.doneTitle)이 없어요") }
                ForEach(stories) { DogDoneRow(style: style, row: $0, showsDate: true, onEditPeriod: onEditPeriod) }
            }
        } else {
            let open = rows.filter { $0.depth == 0 && !$0.item.isDone }
            let done = rows.filter { $0.depth == 0 && $0.item.isDone }
            VStack(alignment: .leading, spacing: 10) {
                if open.isEmpty {
                    emptyCard(store.listTab == .today ? "오늘 할 일이 없어요. 위에 하나 알려줄래요?" : "기간을 정한 할 일이 없어요")
                }
                ForEach(open) { story in
                    DogStoryGroup(style: style, story: story,
                                  tasks: rows.filter { $0.item.parentID == story.item.id }, onEditPeriod: onEditPeriod)
                }
                if !done.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(style.doneTitle) · \(done.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(style.textSecondary)
                            .padding(.top, 8)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)
                        ForEach(done) { DogDoneRow(style: style, row: $0, showsDate: false, onEditPeriod: onEditPeriod) }
                    }
                }
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            DogAvatar(file: style.avatarHappy, size: 40, background: style.sidebar)
            Text(text).font(.system(size: 14, design: .rounded)).foregroundStyle(style.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dogCard(style, radius: style.cardRadius, shadow: 0.07)
    }
}

/// 맨 위 입력줄. ⌘N으로 포커스
private struct DogAddBar: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
    let onAdded: (TodoItem) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                switch style.treat {
                case .tennisBall: TennisBallIcon(filled: true, size: 20)
                case .bone: PawIcon(fill: style.focusAccent, size: 20)
                }
            }
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(style.placeholder))
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .rounded))
                .focused($focused)
                .onSubmit(submit)
                .frame(height: 38)
                .accessibilityLabel("새 할 일")
            Button(action: submit) {
                Text(style.addButton)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(style.textOnAccent)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
            }
            .buttonStyle(DogButtonStyle(fill: style.focusAccent, radius: style.cardRadius - 6))
        }
        .padding(.vertical, 6)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .dogCard(style, radius: style.cardRadius, shadow: 0.08, shadowRadius: 12)
        .overlay(RoundedRectangle(cornerRadius: style.cardRadius, style: .circular).strokeBorder(style.inputBorder, lineWidth: 1.5))
        .onChange(of: store.inlineAdd) { target in
            // ⌘N: 맨 위 입력줄로
            if target == .top {
                focused = true
                store.inlineAdd = nil
            }
        }
    }

    private var placeholder: String {
        store.listTab == .scheduled ? "기간 할 일을 알려주세요 (추가 후 기간 설정)" : style.inputPlaceholder
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

private struct DogStoryGroup: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
    let story: ListRow
    let tasks: [ListRow]
    let onEditPeriod: (TodoItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DogTaskCard(style: style, row: story, onEditPeriod: onEditPeriod)
            if !story.item.isCollapsed {
                ForEach(tasks) { task in
                    if task.item.isDone {
                        DogDoneRow(style: style, row: task, showsDate: false, onEditPeriod: onEditPeriod).padding(.leading, 40)
                    } else {
                        DogTaskCard(style: style, row: task, onEditPeriod: onEditPeriod).padding(.leading, 40)
                    }
                }
            }
            if store.inlineAdd == .sub(story.item.id) {
                DogSubAddRow(style: style, storyID: story.item.id).padding(.leading, 40)
            }
        }
    }
}

private struct DogTaskCard: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
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
                DogCheckbox(style: style, done: false, size: isTask ? 20 : 24).frame(width: 44, height: isTask ? 36 : 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.title) 완료로 표시")
            .storyCompletionDialog(item, isPresented: $confirmingDone, store: store)
            .padding(.trailing, -6)

            VStack(alignment: .leading, spacing: isTask ? 4 : 6) {
                HStack(spacing: 6) {
                    if isStory {
                        Button { store.setCollapsed(item, !item.isCollapsed) } label: {
                            Image(systemName: item.isCollapsed ? "chevron.right" : "chevron.down")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(style.textSecondary)
                                .frame(width: 16, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.isCollapsed ? "\(item.title) 펼치기" : "\(item.title) 접기")
                    }
                    if store.renamingID == item.id {
                        RenameField(item: item)
                            .font(.system(size: isTask ? 14 : 15, design: .rounded))
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(RoundedRectangle(cornerRadius: 8, style: .circular).fill(.white))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .circular).strokeBorder(style.focusAccent, lineWidth: 1.5))
                    } else {
                        Text(item.title)
                            .font(.system(size: isTask ? 14 : 15, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .onTapGesture(count: 2) { store.beginRename(item) }
                            .accessibilityAction(named: "제목 수정") { store.beginRename(item) }
                    }
                }
                metaLine
            }

            Spacer(minLength: 8)

            // 마우스를 올리면 나타나는 버튼
            if hovering || TaskRowDebug.alwaysShowActions {
                HStack(spacing: 6) {
                    if row.depth == 0 {
                        Button { store.beginAdd(.sub(item.id)) } label: {
                            Text("+ 태스크")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                        }
                        .buttonStyle(DogButtonStyle(fill: style.softButton, radius: 14))
                        .fixedSize()
                        .accessibilityLabel("\(item.title)에 하위 태스크 추가")
                    }
                    Menu { menu } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(style.text)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(style.softButton))
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
                    PawIcon(fill: style.textOnAccent, size: isTask ? 12 : 14)
                    Text(isActive ? style.focusButtonActive : style.focusButton)
                        .font(.system(size: isTask ? 12 : 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(style.textOnAccent)
                .padding(.horizontal, isTask ? 12 : 16)
                .frame(height: isTask ? 32 : 38)
            }
            .buttonStyle(DogButtonStyle(fill: isActive ? style.focusAccent : style.softButton, radius: isTask ? 16 : 19,
                                        shadow: isActive ? style.focusAccent.opacity(0.4) : .clear))
            .fixedSize()
            .accessibilityLabel("\(item.title) 집중하기")
            .accessibilityAddTraits(isActive ? .isSelected : [])
        }
        .padding(.vertical, isTask ? 6 : 10)
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .background {
            let shape = RoundedRectangle(cornerRadius: isTask ? style.cardRadius - 4 : style.cardRadius, style: .circular)
            shape.fill(isActive ? style.activeRowBg : .white)
                .shadow(color: isActive ? style.focusAccent.opacity(0.30) : style.shadow.opacity(0.07),
                        radius: isActive ? 9 : 6, y: isActive ? 6 : 2)
                .overlay { if isActive { shape.strokeBorder(style.focusAccent, lineWidth: 2) } }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu { menu }
    }

    private var menu: some View {
        TaskMenuItems(item: item, depth: row.depth,
                      onToggleDone: { store.requestToggleDone(item, confirm: $confirmingDone) },
                      onEditPeriod: { onEditPeriod(item) })
    }

    /// 칩 · 기간 · 집중 시간 · 테니스공/뼈다귀 · 1/3
    private var metaLine: some View {
        let counts = store.pomoCounts(item)
        let n = max(counts.est, counts.done)
        return HStack(spacing: 10) {
            if !isTask || item.project != store.parent(of: item)?.project {
                Text(item.project.rawValue)
                    .font(.system(size: isTask ? 11 : 12, weight: .semibold, design: .rounded))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 10)
                    .background(style.chip(item.project), in: Capsule(style: .circular))
                    .fixedSize()
            }
            if let due = item.dueDate { DogPeriodChip(style: style, start: item.startDate, due: due) }
            if let m = item.focusMinutes {
                HStack(spacing: 3) {
                    Image(systemName: "timer").font(.system(size: 10, weight: .semibold))
                    Text("\(m)분")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(style.sidebar, in: Capsule(style: .circular))
                .fixedSize()
                .accessibilityLabel("집중 \(m)분")
            }
            HStack(spacing: style.treat == .tennisBall ? 3 : 2) {
                ForEach(0..<min(n, 6), id: \.self) { i in
                    TreatIcon(treat: style.treat, filled: i < counts.done, size: style.treat == .bone ? (isTask ? 16 : 18) : (isTask ? 13 : 15))
                }
                if n > 6 { Text("+\(n - 6)").font(.system(size: 11, weight: .semibold, design: .rounded)) }
            }
            Text("\(counts.done)/\(counts.est)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .fixedSize()
                .accessibilityLabel("\(style.treatNoun) \(counts.est)개 중 \(counts.done)개")
            if let p = store.taskProgress(item) {
                Text("태스크 \(p.done)/\(p.total)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(p.done == p.total ? style.strong : style.textSecondary)
                    .fixedSize()
            }
        }
        .foregroundStyle(style.textSecondary)
    }
}

/// 기간 칩: 마감이 지났거나 오늘이면 강조, 3일 이내면 accent 연하게
private struct DogPeriodChip: View {
    let style: DogStyle
    let start: Date?
    let due: Date

    var body: some View {
        let days = Period.daysLeft(until: due)
        Text("\(Period.text(start: start, due: due)) · \(Period.ddayText(until: due))")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(days <= 0 ? style.strong : style.text)
            .lineLimit(1)
            .fixedSize()
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(days <= 3 ? style.focusAccent.opacity(days <= 0 ? 0.35 : 0.2) : style.sidebar, in: Capsule(style: .circular))
            .accessibilityLabel("기간 \(Period.text(start: start, due: due)), \(Period.ddayText(until: due))")
    }
}

/// 원형 체크박스. 완료면 accent 채움 + 체크
struct DogCheckbox: View {
    let style: DogStyle
    let done: Bool
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            if done {
                Circle().fill(style.focusAccent)
                Path { p in
                    p.move(to: CGPoint(x: 5, y: 12.5)); p.addLine(to: CGPoint(x: 9.5, y: 17)); p.addLine(to: CGPoint(x: 19, y: 7.5))
                }
                .applying(CGAffineTransform(scaleX: size * 0.54 / 24, y: size * 0.54 / 24))
                .stroke(style.textOnAccent, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.54, height: size * 0.54)
            } else {
                Circle().fill(.white)
                Circle().strokeBorder(style.checkboxBorder, lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 완료한 할 일 줄
private struct DogDoneRow: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
    let row: ListRow
    let showsDate: Bool
    let onEditPeriod: (TodoItem) -> Void

    private var item: TodoItem { row.item }

    var body: some View {
        let counts = store.pomoCounts(item)
        HStack(spacing: 10) {
            Button { store.toggleDone(item) } label: {
                DogCheckbox(style: style, done: true, size: row.depth == 1 ? 20 : 24).frame(width: 44, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.title) 완료 취소")
            .padding(.trailing, -6)

            Text(item.title)
                .font(.system(size: row.depth == 1 ? 14 : 15, design: .rounded))
                .strikethrough(true, color: style.textSecondary)
                .lineLimit(1)
            if let p = store.taskProgress(item) {
                Text("태스크 \(p.total)개").font(.system(size: 12, design: .rounded))
            }
            Spacer(minLength: 8)
            if showsDate, let at = item.completedAt {
                Text(Self.dateFormatter.string(from: at)).font(.system(size: 12, design: .rounded))
            }
            Text("\(counts.done)/\(counts.est)").font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(style.textSecondary)
        .padding(.leading, 6)
        .padding(.trailing, 14)
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

/// 스토리 아래 태스크 입력 카드
private struct DogSubAddRow: View {
    @EnvironmentObject var store: AppStore
    let style: DogStyle
    let storyID: UUID
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            PawIcon(fill: style.focusAccent, size: 16)
            TextField("", text: $text, prompt: Text("태스크 이름을 적고 Enter").foregroundColor(style.placeholder))
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .rounded))
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
        .dogCard(style, radius: style.cardRadius - 4)
        .overlay(RoundedRectangle(cornerRadius: style.cardRadius - 4, style: .circular).strokeBorder(style.focusAccent, lineWidth: 1.5))
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
