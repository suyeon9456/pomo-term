import AppKit
import Foundation
import UserNotifications

final class AppStore: ObservableObject {
    @Published var todos: [TodoItem] = [] { didSet { save() } }
    @Published var settings = AppSettings() { didSet { settingsChanged(oldValue) } }
    @Published var selectedTodoID: UUID? { didSet { save() } }
    @Published var todayCount = 0 { didSet { save() } }
    @Published var todayFocusMinutes = 0 { didSet { save() } }

    @Published private(set) var mode: TimerMode = .focus
    @Published private(set) var remaining: Int = 25 * 60
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
        remaining = duration(for: mode)
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

    var totalSeconds: Int { duration(for: mode) }
    var progress: Double { totalSeconds == 0 ? 0 : 1 - Double(remaining) / Double(totalSeconds) }
    var timeString: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var selectedTodo: TodoItem? { todos.first { $0.id == selectedTodoID && !$0.isDone } }
    var cycleLength: Int { max(1, settings.longBreakInterval) }

    func duration(for mode: TimerMode) -> Int {
        minutes(for: mode, in: settings) * 60
    }

    func toggle() { isRunning ? pause() : start() }

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
        remaining = duration(for: mode)
        addLog("↺ 타이머 초기화", .info)
    }

    func skip() { advance(completed: false) }

    func switchMode(_ newMode: TimerMode) {
        stopTimer()
        mode = newMode
        remaining = duration(for: newMode)
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
                todayFocusMinutes += settings.focusMinutes
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
            mode = .focus
            session = session % cycleLength + 1
            addLog("· break 종료, 다음 focus 준비", .warn)
        }
        remaining = duration(for: mode)
        if completed {
            notify(finished: finished)
            if settings.autoStartNext { start() }
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
        }
    }

    private func settingsChanged(_ old: AppSettings) {
        save()
        if session > cycleLength { session = 1 }
        // 멈춰 있고 아직 시작 전인 타이머만 새 시간으로 맞춤
        if !isRunning && remaining == minutes(for: mode, in: old) * 60 {
            remaining = duration(for: mode)
        }
    }

    private func minutes(for mode: TimerMode, in s: AppSettings) -> Int {
        switch mode {
        case .focus: return s.focusMinutes
        case .shortBreak: return s.shortBreakMinutes
        case .longBreak: return s.longBreakMinutes
        }
    }

    // MARK: - Derived values

    /// 지금 보고 있는 목록
    var orderedTodos: [TodoItem] { orderedTodos(listTab) }

    /// 미완료 → 완료 순서. 화면의 # 번호와 명령어의 <#>가 이 순서를 따름
    /// - today: 기간 없는 할 일 + 기간이 시작됐거나 마감이 지난 기간 할 일
    /// - scheduled: 기간 할 일 전체, 마감일 순
    /// 완료한 할 일은 완료한 날까지만 보임 (데이터에는 남음)
    func orderedTodos(_ tab: ListTab, now: Date = Date()) -> [TodoItem] {
        let today = Period.startOfDay(now)
        let visible = todos.filter { t in
            guard t.isDone else { return true }
            return t.completedAt.map { Period.startOfDay($0) >= today } ?? true
        }
        let list: [TodoItem]
        switch tab {
        case .today:
            list = visible.filter { t in
                guard t.isScheduled else { return true }
                return (t.startDate ?? .distantPast) <= today
            }
        case .scheduled:
            list = visible.filter(\.isScheduled).sorted {
                ($0.dueDate ?? .distantFuture, $0.startDate ?? .distantPast) < ($1.dueDate ?? .distantFuture, $1.startDate ?? .distantPast)
            }
        }
        return list.filter { !$0.isDone } + list.filter(\.isDone)
    }

    var openCount: Int { orderedTodos.filter { !$0.isDone }.count }
    var doneCount: Int { orderedTodos.filter(\.isDone).count }
    var remainingPomodoros: Int {
        orderedTodos.filter { !$0.isDone }.reduce(0) { $0 + max(0, $1.estimatedPomodoros - $1.completedPomodoros) }
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
        return "\(next.key) break \(minutes(for: next, in: settings))m"
    }

    var focusTimeText: String {
        let m = todayFocusMinutes
        return (m >= 60 ? "\(m / 60)h " : "") + "\(m % 60)m"
    }

    /// ●●○ 형태. 6개를 넘으면 칸이 밀리지 않게 ●3/20 처럼 숫자로
    static func pomoBar(_ item: TodoItem) -> String {
        let n = max(item.estimatedPomodoros, item.completedPomodoros)
        guard n <= 6 else { return (item.completedPomodoros > 0 ? "●" : "○") + "\(item.completedPomodoros)/\(n)" }
        return (0..<n).map { $0 < item.completedPomodoros ? "●" : "○" }.joined()
    }

    // MARK: - Log

    func addLog(_ text: String, _ kind: LogEntry.Kind = .plain) {
        log = Array((log + [LogEntry(text: text, kind: kind)]).suffix(Self.logLimit))
    }

    // MARK: - Todos

    func addTodo(_ title: String, estimate: Int = 1, project: Project = .work,
                 period: (start: Date?, due: Date)? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var item = TodoItem(title: trimmed, estimatedPomodoros: estimate, project: project)
        item.startDate = period?.start
        item.dueDate = period?.due
        todos.append(item)
        if selectedTodo == nil, orderedTodos(.today).contains(where: { $0.id == item.id }) { selectedTodoID = item.id }
        let suffix = period.map { "  " + Period.text(start: $0.start, due: $0.due) } ?? ""
        addLog("+ added \"\(trimmed)\"\(suffix)", .add)
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

    func toggleDone(_ item: TodoItem) {
        guard let i = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[i].isDone.toggle()
        todos[i].completedAt = todos[i].isDone ? Date() : nil
        if selectedTodo == nil { selectedTodoID = orderedTodos(.today).first { !$0.isDone }?.id }
        let t = todos[i]
        addLog(t.isDone ? "✓ done \(t.title)" : "↩ reopen \(t.title)", t.isDone ? .success : .info)
    }

    func select(_ item: TodoItem) {
        guard !item.isDone else { return }
        selectedTodoID = item.id
        addLog("→ focus: \(item.title)", .success)
    }

    func update(_ item: TodoItem, _ change: (inout TodoItem) -> Void) {
        guard let i = todos.firstIndex(where: { $0.id == item.id }) else { return }
        change(&todos[i])
    }

    func delete(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
        if selectedTodo == nil { selectedTodoID = orderedTodos(.today).first { !$0.isDone }?.id }
        addLog("- removed \"\(item.title)\"", .info)
    }

    func clearDone() { todos.removeAll { $0.isDone } }

    // MARK: - Commands

    static let helpText = "start · pause · reset · skip · add <할 일> [M/D~M/D] · done <#> · focus <#> · ls today|sched · due <#> <M/D~M/D> (해제: -) · mode <m> · mini · clear"

    func run(command raw: String) {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        addLog("❯ \(line)", .echo)

        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        let head = parts[0].lowercased()
        let arg = parts.dropFirst().joined(separator: " ")
        let list = orderedTodos
        let picked = Int(arg).flatMap { list.indices.contains($0 - 1) ? list[$0 - 1] : nil }
        let fail = { (msg: String) in self.addLog("✗ \(msg)", .error) }

        switch head {
        case "start", "s": start()
        case "pause", "p": pause()
        case "reset", "r": reset()
        case "skip": skip()
        case "add", "a":
            // 마지막 단어가 기간이면 기간 할 일로 추가 (예: add 리팩터링 10/27~10/31)
            var title = arg
            var period: (start: Date?, due: Date)?
            if parts.count > 2, let p = Period.parse(parts.last!) {
                period = p
                title = parts.dropFirst().dropLast().joined(separator: " ")
            }
            if title.isEmpty { fail("usage: add <할 일> [M/D~M/D]") }
            else if listTab == .scheduled && period == nil { fail("scheduled에는 기간이 필요해요: add <할 일> ~M/D") }
            else { addTodo(title, period: period) }
        case "ls":
            switch arg.lowercased() {
            case "today", "t": listTab = .today
            case "sched", "scheduled", "s": listTab = .scheduled
            default: fail("usage: ls today|sched")
            }
        case "due":
            let num = parts.count > 1 ? Int(parts[1]) : nil
            guard let num, list.indices.contains(num - 1), parts.count == 3 else {
                fail("usage: due <#> <M/D~M/D>   (기간 해제: due <#> -)"); break
            }
            if parts[2] == "-" { setPeriod(list[num - 1], start: nil, due: nil) }
            else if let p = Period.parse(parts[2]) { setPeriod(list[num - 1], start: p.start, due: p.due) }
            else { fail("기간 형식: 11/3, ~11/3, 10/27~10/31, ~내일") }
        case "done", "d":
            if let picked { toggleDone(picked) } else { fail("usage: done <#>") }
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
    }

    private func save() {
        guard persistent, !loading else { return }
        let s = SavedState(todos: todos, settings: settings, selectedTodoID: selectedTodoID,
                           todayCount: todayCount, todayFocusMinutes: todayFocusMinutes, todayDate: todayDate)
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
        s.selectedTodoID = s.todos[0].id
        s.session = 2
        s.remaining = 18 * 60 + 42
        s.todayCount = 3
        s.todayFocusMinutes = 75
        s.addLog("✓ focus #1 완료 → 디자인 시스템 버튼 컴포넌트 정리 (1/3)", .success)
        s.addLog("· short break 05:00 종료", .warn)
        return s
    }
}
