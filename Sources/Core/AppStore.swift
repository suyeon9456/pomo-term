import AppKit
import Foundation
import UserNotifications

final class AppStore: ObservableObject {
    @Published var todos: [TodoItem] = [] { didSet { save() } }
    @Published var settings = AppSettings() { didSet { settingsChanged() } }
    @Published var selectedTodoID: UUID? {
        didSet {
            save()
            // 할 일마다 집중 시간이 다를 수 있으므로 시작 전 타이머는 새 할 일 기준으로
            if oldValue != selectedTodoID { refreshIdleTimer() }
        }
    }
    @Published var todayCount = 0 { didSet { save() } }
    @Published var todayFocusMinutes = 0 { didSet { save() } }
    /// 끝까지 마친 휴식만 기록 (건너뛴 휴식은 제외)
    @Published var todayBreakCount = 0 { didSet { save() } }
    @Published var todayBreakMinutes = 0 { didSet { save() } }

    @Published private(set) var mode: TimerMode = .focus
    @Published private(set) var remaining: Int = 25 * 60
    /// 지금 세션의 전체 길이. 진행 중에 설정을 바꿔도 이번 세션은 그대로, 다음 세션부터 적용
    @Published private(set) var totalSeconds: Int = 25 * 60
    @Published private(set) var isRunning = false
    /// 긴 휴식 주기 안에서 몇 번째 집중인지 (1...longBreakInterval)
    @Published private(set) var session = 1
    /// 최근 6줄만 유지
    @Published private(set) var log: [LogEntry] = []
    /// 메인 창에서 보고 있는 목록. 화면의 # 번호와 명령어의 <#>가 이 목록 기준
    @Published var listTab: ListTab = .today

    /// 화면 밖(미니 타이머, 명령어)에서 창을 열기 위한 연결 고리. 앱이 시작될 때 채워짐
    var openMainWindow: (() -> Void)?
    var toggleMiniTimer: (() -> Void)?

    private var todayDate = Date()
    private var timer: Timer?
    private var endDate: Date?
    private var loading = false
    private let persistent: Bool

    private static let logLimit = 6
    private var dayChangeObserver: NSObjectProtocol?

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    /// persistent가 false면 data.json을 읽거나 쓰지 않음 (스냅샷용)
    init(persistent: Bool = true) {
        self.persistent = persistent
        if persistent { load() }
        loadFullDuration()
        addLog("pomo v1.0 · help 를 입력하면 명령어를 볼 수 있어요", .info)
        if Self.canNotify {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        // 자정이 지나면 오늘 목록·D-day·오늘 통계를 다시 계산
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.rollDayIfNeeded()
            self?.objectWillChange.send()
        }
    }

    // 앱 번들 밖(테스트·스냅샷 실행)에서는 알림 센터를 쓸 수 없음
    private static var canNotify: Bool { Bundle.main.bundleIdentifier != nil }

    // MARK: - Timer

    var progress: Double { totalSeconds == 0 ? 0 : 1 - Double(remaining) / Double(totalSeconds) }
    var timeString: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var selectedTodo: TodoItem? { todos.first { $0.id == selectedTodoID && !$0.isDone } }
    var cycleLength: Int { max(1, settings.longBreakInterval) }

    func duration(for mode: TimerMode) -> Int {
        minutes(for: mode, in: settings) * 60
    }

    func toggle() { isRunning ? pause() : start() }

    private func loadFullDuration() {
        totalSeconds = duration(for: mode)
        remaining = totalSeconds
    }

    /// 아직 시작하지 않은(가득 찬) 타이머만 새 길이로 맞춤
    private func refreshIdleTimer() {
        if !isRunning && remaining == totalSeconds { loadFullDuration() }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remaining))
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        addLog("▶ \(mode.key) 시작", mode == .focus ? .success : .warn)
    }

    func pause() {
        guard isRunning else { return }
        stopTimer()
        addLog("❚❚ 일시정지", .info)
    }

    func reset() {
        stopTimer()
        loadFullDuration()
        addLog("↺ 타이머 초기화", .info)
    }

    func skip() { advance(completed: false) }

    func switchMode(_ newMode: TimerMode) {
        stopTimer()
        mode = newMode
        loadFullDuration()
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        endDate = nil
    }

    private func tick() {
        guard let endDate else { return }
        let left = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        if left != remaining { remaining = left }
        if left == 0 { advance(completed: true) }
    }

    private func advance(completed: Bool) {
        stopTimer()
        let finished = mode
        if finished == .focus {
            if completed {
                rollDayIfNeeded()
                todayCount += 1
                todayFocusMinutes += totalSeconds / 60
                var detail = ""
                if let id = selectedTodo?.id, let i = todos.firstIndex(where: { $0.id == id }) {
                    todos[i].completedPomodoros += 1
                    let t = todos[i]
                    detail = " → \(t.title) (\(t.completedPomodoros)/\(t.estimatedPomodoros))"
                }
                addLog("✓ focus #\(session) 완료\(detail)", .success)
            }
            mode = session % cycleLength == 0 ? .longBreak : .shortBreak
            if !completed { addLog("» focus 건너뜀 → \(mode.key) break", .info) }
        } else {
            if completed {
                rollDayIfNeeded()
                todayBreakCount += 1
                todayBreakMinutes += totalSeconds / 60
                addLog("· \(finished.key) break \(totalSeconds / 60)m 완료 · 오늘 휴식 \(breakTimeText)", .warn)
            } else {
                addLog("» \(finished.key) break 건너뜀", .info)
            }
            mode = .focus
            session = session % cycleLength + 1
        }
        loadFullDuration()
        if completed {
            notify(finished: finished)
            // 집중이 끝나 휴식으로 넘어왔으면 autoStartBreak, 휴식이 끝나 집중으로 넘어왔으면 autoStartFocus
            if mode == .focus ? settings.autoStartFocus : settings.autoStartBreak { start() }
        }
    }

    private func notify(finished: TimerMode) {
        if settings.playSound { NSSound(named: "Glass")?.play() }
        guard Self.canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = finished == .focus ? "focus 완료" : "break 종료"
        content.body = finished == .focus
            ? "\(mode.key) break \(minutes(for: mode, in: settings))m 시작할 시간이에요."
            : "다시 집중할 시간이에요\(selectedTodo.map { ": \($0.title)" } ?? ".")"
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func rollDayIfNeeded() {
        if !Calendar.current.isDateInToday(todayDate) {
            todayDate = Date()
            todayCount = 0
            todayFocusMinutes = 0
            todayBreakCount = 0
            todayBreakMinutes = 0
        }
    }

    private func settingsChanged() {
        save()
        if session > cycleLength { session = 1 }
        refreshIdleTimer()
    }

    /// focus는 현재 할 일의 집중 시간이 있으면 그 값
    private func minutes(for mode: TimerMode, in s: AppSettings) -> Int {
        switch mode {
        case .focus: return selectedTodo?.focusMinutes ?? s.focusMinutes
        case .shortBreak: return s.shortBreakMinutes
        case .longBreak: return s.longBreakMinutes
        }
    }

    // MARK: - Derived values

    /// 지금 보고 있는 목록 (스토리와 하위 태스크를 펼친 순서)
    var orderedTodos: [TodoItem] { orderedTodos(listTab) }

    func orderedTodos(_ tab: ListTab, now: Date = Date()) -> [TodoItem] { rows(tab, now: now).map(\.item) }

    /// 화면의 # 번호와 명령어의 <#>가 이 순서를 따름. 스토리는 미완료 → 완료 순, 하위 태스크는 추가한 순서
    /// - today: 기간 없는 할 일 + 시작일이 오늘이거나 지난 기간 할 일 (마감일만 있는 할 일은 scheduled에만)
    /// - scheduled: 기간 할 일 전체, 마감일 순
    /// 탭 분류는 스토리 기준이고 하위 태스크는 스토리를 따라감.
    /// 완료한 스토리는 완료한 날까지만 보임 (데이터에는 남음). done 탭은 완료한 스토리 전체를 최근 순으로
    func rows(_ tab: ListTab, now: Date = Date()) -> [ListRow] {
        let today = Period.startOfDay(now)
        let visible = todos.filter { t in
            guard t.parentID == nil else { return false }
            guard t.isDone else { return true }
            return t.completedAt.map { Period.startOfDay($0) >= today } ?? true
        }
        let list: [TodoItem]
        switch tab {
        case .done:
            list = todos.filter { $0.parentID == nil && $0.isDone }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .today:
            list = visible.filter { t in
                guard t.isScheduled else { return true }
                guard let start = t.startDate else { return false }
                return start <= today
            }
        case .scheduled:
            list = visible.filter(\.isScheduled).sorted {
                ($0.dueDate ?? .distantFuture, $0.startDate ?? .distantPast) < ($1.dueDate ?? .distantFuture, $1.startDate ?? .distantPast)
            }
        }
        let stories = list.filter { !$0.isDone } + list.filter(\.isDone)
        return stories.enumerated().flatMap { i, story in
            let kids = children(of: story)
            return [ListRow(number: "\(i + 1)", item: story, depth: 0)]
                + kids.enumerated().map { j, task in
                    ListRow(number: "\(i + 1).\(j + 1)", item: task, depth: 1, isLastChild: j == kids.count - 1)
                }
        }
    }

    func children(of item: TodoItem) -> [TodoItem] { todos.filter { $0.parentID == item.id } }
    func parent(of item: TodoItem) -> TodoItem? { item.parentID.flatMap { id in todos.first { $0.id == id } } }
    func hasChildren(_ item: TodoItem) -> Bool { todos.contains { $0.parentID == item.id } }

    /// 하위 태스크가 있는 스토리는 집계용이므로, 개수·남은 뽀모도로는 실제 작업 단위(잎)로 셈
    private var leafRows: [TodoItem] { orderedTodos.filter { !hasChildren($0) } }
    var openCount: Int { leafRows.filter { !$0.isDone }.count }
    var doneCount: Int { leafRows.filter(\.isDone).count }
    var remainingPomodoros: Int {
        leafRows.filter { !$0.isDone }.reduce(0) { $0 + max(0, $1.estimatedPomodoros - $1.completedPomodoros) }
    }

    /// 스토리는 하위 태스크 합계(+ 스토리에 직접 쌓은 뽀모도로)
    func pomoCounts(_ item: TodoItem) -> (done: Int, est: Int) {
        let kids = children(of: item)
        guard !kids.isEmpty else { return (item.completedPomodoros, item.estimatedPomodoros) }
        return (item.completedPomodoros + kids.reduce(0) { $0 + $1.completedPomodoros },
                kids.reduce(0) { $0 + $1.estimatedPomodoros })
    }

    /// 스토리의 태스크 진행률 (완료/전체). 하위 태스크가 없으면 nil
    func taskProgress(_ item: TodoItem) -> (done: Int, total: Int)? {
        let kids = children(of: item)
        return kids.isEmpty ? nil : (kids.filter(\.isDone).count, kids.count)
    }

    func pomoBar(for item: TodoItem) -> String {
        let c = pomoCounts(item)
        return Self.pomoBar(done: c.done, est: c.est)
    }

    /// 다음에 집중할 후보: 같은 스토리의 열린 태스크 → 오늘 목록의 첫 열린 작업(열린 태스크가 있는 스토리는 건너뜀)
    private func nextFocus(after item: TodoItem?) -> TodoItem? {
        if let parent = item.flatMap(parent(of:)), let sibling = children(of: parent).first(where: { !$0.isDone }) {
            return sibling
        }
        return orderedTodos(.today).first { t in !t.isDone && !children(of: t).contains { !$0.isDone } }
    }

    /// 모드별 조절 단위와 범위 (설정 창과 같은 범위)
    static func minuteStep(for mode: TimerMode) -> Int { mode == .shortBreak ? 1 : 5 }
    static func minuteRange(for mode: TimerMode) -> ClosedRange<Int> {
        switch mode {
        case .focus: return 1...120
        case .shortBreak: return 1...60
        case .longBreak: return 1...90
        }
    }

    func setMinutes(_ minutes: Int, for mode: TimerMode) {
        let m = min(max(minutes, Self.minuteRange(for: mode).lowerBound), Self.minuteRange(for: mode).upperBound)
        switch mode {
        case .focus: settings.focusMinutes = m
        case .shortBreak: settings.shortBreakMinutes = m
        case .longBreak: settings.longBreakMinutes = m
        }
        addLog("· \(mode.key) \(m)m 으로 설정", .info)
    }

    /// −/+ 버튼: 지금 모드의 시간을 한 단위씩 조절.
    /// 현재 할 일에 집중 시간이 따로 있으면 그 할 일의 시간을 조절
    func adjustCurrentMinutes(by steps: Int) {
        let current = minutes(for: mode, in: settings)
        let step = Self.minuteStep(for: mode)
        // 25 → 30처럼 단위에 맞춰 이동 (27에서 +5면 30)
        let next = steps > 0 ? (current / step + 1) * step : ((current + step - 1) / step - 1) * step
        if mode == .focus, let task = selectedTodo, task.focusMinutes != nil {
            setFocusMinutes(task, next)
        } else {
            setMinutes(next, for: mode)
        }
    }

    /// 할 일별 집중 시간. nil이면 기본 집중 시간으로
    func setFocusMinutes(_ item: TodoItem, _ minutes: Int?) {
        let range = Self.minuteRange(for: .focus)
        let m = minutes.map { min(max($0, range.lowerBound), range.upperBound) }
        update(item) { $0.focusMinutes = m }
        refreshIdleTimer()
        addLog("· time \(item.title)  \(m.map { "\($0)m" } ?? "기본(\(settings.focusMinutes)m)")", .info)
    }

    /// 현재 할 일에 집중 시간이 따로 정해져 있는지
    var usesTaskFocusMinutes: Bool { selectedTodo?.focusMinutes != nil }

    /// 모드별 지금 설정된 시간(분). focus는 현재 할 일의 집중 시간을 반영
    func minutesSetting(for mode: TimerMode) -> Int { minutes(for: mode, in: settings) }

    /// 지금 모드가 끝나면 넘어갈 모드
    var nextMode: TimerMode {
        guard mode == .focus else { return .focus }
        return session % cycleLength == 0 ? .longBreak : .shortBreak
    }

    /// 목록별 남은 작업 수 (하위 태스크가 있는 스토리는 태스크로 셈). done은 완료한 스토리 수
    func openLeafCount(_ tab: ListTab) -> Int {
        if tab == .done { return rows(.done).filter { $0.depth == 0 }.count }
        return rows(tab).filter { !$0.item.isDone && !hasChildren($0.item) }.count
    }

    func tabLabel(for mode: TimerMode) -> String { "\(mode.key) \(minutes(for: mode, in: settings))m" }

    func asciiBar(width: Int, percent: Bool = true) -> String {
        let p = min(1, max(0, progress))
        let filled = Int((p * Double(width)).rounded())
        let bar = "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled) + "]"
        guard percent else { return bar }
        let pct = String(Int((p * 100).rounded()))
        return bar + " " + String(repeating: " ", count: max(0, 3 - pct.count)) + pct + "%"
    }

    /// 지난 세션 ●, 진행 중 ◐, 남은 세션 ○ (휴식 중이면 현재 세션도 ●)
    var cycleBar: String {
        (1...cycleLength).map { i in
            if i < session || (i == session && mode != .focus) { return "●" }
            return i == session ? "◐" : "○"
        }.joined()
    }

    var nextText: String {
        guard mode == .focus else { return tabLabel(for: .focus) }
        let next: TimerMode = session % cycleLength == 0 ? .longBreak : .shortBreak
        return "\(next.key) break \(minutes(for: next, in: settings))m" + (settings.autoStartBreak ? " (auto)" : "")
    }

    var focusTimeText: String { Self.durationText(todayFocusMinutes) }
    /// 2회 · 10m
    var breakTimeText: String { "\(todayBreakCount)회 · \(Self.durationText(todayBreakMinutes))" }

    static func durationText(_ minutes: Int) -> String {
        (minutes >= 60 ? "\(minutes / 60)h " : "") + "\(minutes % 60)m"
    }

    /// ●●○ 형태. 6개를 넘으면 칸이 밀리지 않게 ●3/20 처럼 숫자로
    static func pomoBar(done: Int, est: Int) -> String {
        let n = max(est, done)
        guard n <= 6 else { return (done > 0 ? "●" : "○") + "\(done)/\(n)" }
        return (0..<n).map { $0 < done ? "●" : "○" }.joined()
    }

    // MARK: - Log

    func addLog(_ text: String, _ kind: LogEntry.Kind = .plain) {
        log = Array((log + [LogEntry(text: text, kind: kind)]).suffix(Self.logLimit))
    }

    // MARK: - Todos

    @discardableResult
    func addTodo(_ title: String, estimate: Int = 1, project: Project = .work,
                 period: (start: Date?, due: Date)? = nil) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var item = TodoItem(title: trimmed, estimatedPomodoros: estimate, project: project)
        item.startDate = period?.start
        item.dueDate = period?.due
        todos.append(item)
        if selectedTodo == nil, orderedTodos(.today).contains(where: { $0.id == item.id }) { selectedTodoID = item.id }
        let suffix = period.map { "  " + Period.text(start: $0.start, due: $0.due) } ?? ""
        addLog("+ added \"\(trimmed)\"\(suffix)", .add)
        return item
    }

    /// 지금 열려 있는 목록 안 입력줄 (한 번에 하나만)
    @Published var inlineAdd: InlineAdd?

    /// 목록 안 입력줄에서 Enter. scheduled 탭의 맨 아래 추가면 임시 기간(오늘~일주일)을 넣음
    @discardableResult
    func submitInlineAdd(_ target: InlineAdd, _ title: String) -> TodoItem? {
        switch target {
        case .top:
            return addTodo(title, period: listTab == .scheduled ? Self.defaultSchedulePeriod : nil)
        case .sub(let id):
            guard let story = todos.first(where: { $0.id == id }) else { return nil }
            return addSubtask(to: story, title)
        }
    }

    static var defaultSchedulePeriod: (start: Date?, due: Date) {
        let today = Period.startOfDay(Date())
        return (nil, Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today)
    }

    func beginAdd(_ target: InlineAdd) {
        if case .sub(let id) = target, let story = todos.first(where: { $0.id == id }) {
            setCollapsed(story, false)
        }
        renamingID = nil
        inlineAdd = target
    }

    /// 제목을 고치는 중인 할 일 (한 번에 하나만)
    @Published var renamingID: UUID?

    func beginRename(_ item: TodoItem) {
        inlineAdd = nil
        renamingID = item.id
    }

    func rename(_ item: TodoItem, _ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.title else { return }
        update(item) { $0.title = trimmed }
        addLog("· mv \"\(item.title)\" → \"\(trimmed)\"", .info)
    }

    func setPeriod(_ item: TodoItem, start: Date?, due: Date?) {
        update(item) {
            $0.startDate = due == nil ? nil : start.map(Period.startOfDay)
            $0.dueDate = due.map(Period.startOfDay)
        }
        if let due {
            addLog("· period \(item.title)  \(Period.text(start: start, due: due))", .info)
        } else {
            addLog("· period 해제 → today: \(item.title)", .info)
        }
    }

    /// 하위 태스크 추가. 태그는 스토리를 따르고, 기간은 비워두면 스토리 기간을 따름
    @discardableResult
    func addSubtask(to story: TodoItem, _ title: String, period: (start: Date?, due: Date)? = nil) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, story.parentID == nil else { return nil }
        var item = TodoItem(title: trimmed, project: story.project)
        item.parentID = story.id
        item.startDate = period?.start
        item.dueDate = period?.due
        todos.append(item)
        update(story) { $0.isCollapsed = false }
        addLog("+ added \"\(trimmed)\" → \(story.title)", .add)
        return item
    }

    func openChildrenCount(_ item: TodoItem) -> Int { children(of: item).filter { !$0.isDone }.count }

    /// 열린 하위 태스크가 있는 스토리를 완료할 때 includeTasks가 true면 태스크도 함께 완료
    func toggleDone(_ item: TodoItem, includeTasks: Bool = false) {
        guard let i = todos.firstIndex(where: { $0.id == item.id }) else { return }
        let now = Date()
        todos[i].isDone.toggle()
        todos[i].completedAt = todos[i].isDone ? now : nil
        let t = todos[i]
        if t.isDone && includeTasks {
            for k in todos.indices where todos[k].parentID == t.id && !todos[k].isDone {
                todos[k].isDone = true
                todos[k].completedAt = now
            }
        }
        // 완료된 스토리의 태스크를 다시 열면 스토리도 다시 열림
        if !t.isDone, let p = parent(of: t), p.isDone, let pi = todos.firstIndex(where: { $0.id == p.id }) {
            todos[pi].isDone = false
            todos[pi].completedAt = nil
        }
        if selectedTodo == nil { selectedTodoID = nextFocus(after: t)?.id }
        addLog(t.isDone ? "✓ done \(t.title)\(includeTasks ? " (태스크 포함)" : "")" : "↩ reopen \(t.title)",
               t.isDone ? .success : .info)
    }

    func setCollapsed(_ item: TodoItem, _ collapsed: Bool) {
        update(item) { $0.isCollapsed = collapsed }
    }

    /// 스토리의 태그를 바꾸면 같은 태그였던 하위 태스크도 따라 바뀜
    func setProject(_ item: TodoItem, _ project: Project) {
        let old = item.project
        update(item) { $0.project = project }
        for k in todos.indices where todos[k].parentID == item.id && todos[k].project == old {
            todos[k].project = project
        }
    }

    /// 명령어 입력줄 내용
    @Published var commandDraft = ""

    func select(_ item: TodoItem) {
        guard !item.isDone else { return }
        selectedTodoID = item.id
        addLog("→ focus: \(item.title)", .success)
    }

    func update(_ item: TodoItem, _ change: (inout TodoItem) -> Void) {
        guard let i = todos.firstIndex(where: { $0.id == item.id }) else { return }
        change(&todos[i])
    }

    /// 스토리를 지우면 하위 태스크도 함께 지움
    func delete(_ item: TodoItem) {
        let kids = children(of: item).count
        todos.removeAll { $0.id == item.id || $0.parentID == item.id }
        if selectedTodo == nil { selectedTodoID = nextFocus(after: nil)?.id }
        addLog("- removed \"\(item.title)\"\(kids > 0 ? " (태스크 \(kids)개 포함)" : "")", .info)
    }

    func clearDone() {
        let doneIDs = Set(todos.filter(\.isDone).map(\.id))
        todos.removeAll { $0.isDone || $0.parentID.map(doneIDs.contains) == true }
    }

    // MARK: - Commands

    static let helpText = "start · pause · reset · skip · add <할 일> [M/D~M/D] · sub <#> <태스크> · mv <#> <제목> · done <#> [--all|--only] · focus <#> · fold|unfold <#> · ls today|sched|done · due <#> <M/D~M/D> (해제: -) · mode <m> · set focus|short|long <분> · time <#> <분> (기본: -) · mini · clear"

    func run(command raw: String) {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        addLog("❯ \(line)", .echo)

        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        let head = parts[0].lowercased()
        let arg = parts.dropFirst().joined(separator: " ")
        let rowList = rows(listTab)
        // <#>는 "2" 또는 "1.2"
        let find = { (number: String) in rowList.first { $0.number == number }?.item }
        let picked = parts.count > 1 ? find(parts[1]) : nil
        let fail = { (msg: String) in self.addLog("✗ \(msg)", .error) }
        /// 마지막 단어가 기간이면 떼어냄 (예: 리팩터링 10/27~10/31)
        let splitPeriod = { (words: [String]) -> (title: String, period: (start: Date?, due: Date)?) in
            if words.count > 1, let p = Period.parse(words.last!) {
                return (words.dropLast().joined(separator: " "), p)
            }
            return (words.joined(separator: " "), nil)
        }

        switch head {
        case "start", "s": start()
        case "pause", "p": pause()
        case "reset", "r": reset()
        case "skip": skip()
        case "add", "a":
            let (title, period) = splitPeriod(Array(parts.dropFirst()))
            if title.isEmpty { fail("usage: add <할 일> [M/D~M/D]") }
            else if listTab == .scheduled && period == nil { fail("scheduled에는 기간이 필요해요: add <할 일> ~M/D") }
            else { addTodo(title, period: period) }
        case "sub":
            let (title, period) = splitPeriod(Array(parts.dropFirst(2)))
            if let picked, picked.parentID != nil { fail("하위 작업은 두 단계(스토리 > 태스크)까지만 만들 수 있어요") }
            else if let picked, !title.isEmpty { addSubtask(to: picked, title, period: period) }
            else { fail("usage: sub <#> <태스크> [M/D~M/D]") }
        case "mv":
            let title = parts.dropFirst(2).joined(separator: " ")
            if let picked, !title.isEmpty { rename(picked, title) }
            else { fail("usage: mv <#> <새 제목>") }
        case "fold", "unfold":
            if let picked, hasChildren(picked) { setCollapsed(picked, head == "fold") }
            else { fail("usage: \(head) <#>  (하위 태스크가 있는 스토리 번호)") }
        case "ls":
            switch arg.lowercased() {
            case "today", "t": listTab = .today
            case "sched", "scheduled", "s": listTab = .scheduled
            case "done", "d": listTab = .done
            default: fail("usage: ls today|sched|done")
            }
        case "due":
            guard let picked, parts.count == 3 else {
                fail("usage: due <#> <M/D~M/D>   (기간 해제: due <#> -)"); break
            }
            if parts[2] == "-" { setPeriod(picked, start: nil, due: nil) }
            else if let p = Period.parse(parts[2]) { setPeriod(picked, start: p.start, due: p.due) }
            else { fail("기간 형식: 11/3, ~11/3, 10/27~10/31, ~내일") }
        case "done", "d":
            guard let picked else { fail("usage: done <#> [--all|--only]"); break }
            let flag = parts.count > 2 ? parts[2] : nil
            let open = openChildrenCount(picked)
            if !picked.isDone && open > 0 && flag == nil {
                addLog("! 열린 태스크 \(open)개가 있어요 → 모두 완료: done \(parts[1]) --all · 스토리만: done \(parts[1]) --only", .warn)
            } else {
                toggleDone(picked, includeTasks: flag == "--all")
            }
        case "focus", "f":
            if let picked, !picked.isDone { select(picked) }
            else if arg.isEmpty { switchMode(.focus) }
            else { fail("열린 할 일 번호를 입력하세요") }
        case "mode":
            switch arg.lowercased() {
            case "focus": switchMode(.focus)
            case "short": switchMode(.shortBreak)
            case "long": switchMode(.longBreak)
            default: fail("usage: mode focus|short|long")
            }
        case "time", "t":
            guard let picked, parts.count == 3 else {
                fail("usage: time <#> <분>   (기본으로: time <#> -)"); break
            }
            if parts[2] == "-" { setFocusMinutes(picked, nil) }
            else if let n = Int(parts[2]), Self.minuteRange(for: .focus).contains(n) { setFocusMinutes(picked, n) }
            else { fail("집중 시간은 1~120분") }
        case "set":
            let modes: [String: TimerMode] = ["focus": .focus, "short": .shortBreak, "long": .longBreak]
            if parts.count == 3, let m = modes[parts[1].lowercased()], let n = Int(parts[2]),
               Self.minuteRange(for: m).contains(n) {
                setMinutes(n, for: m)
            } else {
                fail("usage: set focus|short|long <분>  (focus 1~120, short 1~60, long 1~90)")
            }
        case "mini", "m": toggleMiniTimer?()
        case "clear": log = []
        case "help": addLog(Self.helpText)
        default: fail("command not found: \(head)  (help 를 입력해보세요)")
        }
    }

    // MARK: - Persistence

    private func load() {
        loading = true
        defer { loading = false }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let s = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        // 예전 버전에서 완료한 할 일은 완료 시각이 없으므로 지금 완료한 것으로 보고 내일부터 숨김
        todos = s.todos.map { t in
            var t = t
            if t.isDone && t.completedAt == nil { t.completedAt = Date() }
            return t
        }
        settings = s.settings
        selectedTodoID = s.selectedTodoID
        todayDate = s.todayDate
        let isToday = Calendar.current.isDateInToday(s.todayDate)
        todayCount = isToday ? s.todayCount : 0
        // 예전 버전은 집중 시간을 따로 저장하지 않았으므로 개수 × 집중 시간으로 추정
        todayFocusMinutes = !isToday ? 0 : s.todayFocusMinutes > 0 ? s.todayFocusMinutes : s.todayCount * s.settings.focusMinutes
        todayBreakCount = isToday ? s.todayBreakCount : 0
        todayBreakMinutes = isToday ? s.todayBreakMinutes : 0
    }

    private func save() {
        guard persistent, !loading else { return }
        let s = SavedState(todos: todos, settings: settings, selectedTodoID: selectedTodoID,
                           todayCount: todayCount, todayFocusMinutes: todayFocusMinutes,
                           todayBreakCount: todayBreakCount, todayBreakMinutes: todayBreakMinutes, todayDate: todayDate)
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    // MARK: - Sample data (스냅샷용)

    static func sample() -> AppStore {
        let s = AppStore(persistent: false)
        func item(_ title: String, _ project: Project, est: Int, done: Int, completed: Bool = false) -> TodoItem {
            var t = TodoItem(title: title, estimatedPomodoros: est, project: project)
            t.completedPomodoros = done
            t.isDone = completed
            return t
        }
        s.todos = [
            item("디자인 시스템 버튼 컴포넌트 정리", .work, est: 3, done: 1),
            item("결제 페이지 API 연동 PR 리뷰", .work, est: 2, done: 0),
            item("Next.js App Router 문서 읽기", .study, est: 2, done: 0),
            item("주간 회고 작성", .personal, est: 1, done: 0),
            item("스탠드업 미팅 노트 정리", .work, est: 1, done: 1, completed: true),
            item("메일함 비우기", .personal, est: 1, done: 1, completed: true),
        ]
        let cal = Calendar.current
        let today = Period.startOfDay(Date())
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today)! }
        func scheduled(_ title: String, _ project: Project, est: Int, start: Int?, due: Int) -> TodoItem {
            var t = TodoItem(title: title, estimatedPomodoros: est, project: project)
            t.startDate = start.map(day)
            t.dueDate = day(due)
            return t
        }
        s.todos += [
            scheduled("결제 모듈 리팩터링", .work, est: 6, start: -1, due: 4),
            scheduled("분기 보고서 제출", .work, est: 2, start: nil, due: -1),
            scheduled("발표 자료 만들기", .work, est: 4, start: nil, due: 7),
            scheduled("정보처리기사 실기", .study, est: 20, start: 5, due: 34),
        ]
        for i in s.todos.indices where s.todos[i].isDone { s.todos[i].completedAt = Date() }
        s.todos[1].focusMinutes = 50
        func task(_ title: String, of storyTitle: String, est: Int, done: Int, completed: Bool = false) -> TodoItem {
            let story = s.todos.first { $0.title == storyTitle }!
            var t = TodoItem(title: title, estimatedPomodoros: est, project: story.project)
            t.parentID = story.id
            t.completedPomodoros = done
            t.isDone = completed
            t.completedAt = completed ? Date() : nil
            return t
        }
        s.todos += [
            task("API 스펙 정리", of: "결제 모듈 리팩터링", est: 1, done: 1, completed: true),
            task("결제 화면 리팩터링", of: "결제 모듈 리팩터링", est: 3, done: 1),
            task("QA 대응", of: "결제 모듈 리팩터링", est: 1, done: 0),
            task("필기 기출 복습", of: "정보처리기사 실기", est: 8, done: 0),
            task("실기 모의고사", of: "정보처리기사 실기", est: 6, done: 0),
        ]
        if let i = s.todos.firstIndex(where: { $0.title == "정보처리기사 실기" }) { s.todos[i].isCollapsed = true }
        s.selectedTodoID = s.todos[0].id
        s.session = 2
        s.remaining = 18 * 60 + 42
        s.todayCount = 3
        s.todayFocusMinutes = 75
        s.todayBreakCount = 2
        s.todayBreakMinutes = 10
        s.addLog("✓ focus #1 완료 → 디자인 시스템 버튼 컴포넌트 정리 (1/3)", .success)
        s.addLog("· short break 05:00 종료", .warn)
        return s
    }
}
