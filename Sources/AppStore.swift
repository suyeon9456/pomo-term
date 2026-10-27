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

    private var todayDate = Date()
    private var timer: Timer?
    private var endDate: Date?
    private var loading = false

    private static let logLimit = 6

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    init() {
        load()
        remaining = duration(for: mode)
        addLog("pomo v1.0 · help 를 입력하면 명령어를 볼 수 있어요", .info)
        if Self.canNotify {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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

    /// 미완료 → 완료 순서. 화면의 # 번호와 명령어의 <#>가 이 순서를 따름
    var orderedTodos: [TodoItem] { todos.filter { !$0.isDone } + todos.filter { $0.isDone } }
    var openCount: Int { todos.filter { !$0.isDone }.count }
    var doneCount: Int { todos.filter { $0.isDone }.count }
    var remainingPomodoros: Int {
        todos.filter { !$0.isDone }.reduce(0) { $0 + max(0, $1.estimatedPomodoros - $1.completedPomodoros) }
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

    static func pomoBar(_ item: TodoItem) -> String {
        let n = max(item.estimatedPomodoros, item.completedPomodoros)
        return (0..<n).map { $0 < item.completedPomodoros ? "●" : "○" }.joined()
    }

    // MARK: - Log

    func addLog(_ text: String, _ kind: LogEntry.Kind = .plain) {
        log = Array((log + [LogEntry(text: text, kind: kind)]).suffix(Self.logLimit))
    }

    // MARK: - Todos

    func addTodo(_ title: String, estimate: Int = 1, project: Project = .work) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed, estimatedPomodoros: estimate, project: project)
        todos.append(item)
        if selectedTodo == nil { selectedTodoID = item.id }
        addLog("+ added \"\(trimmed)\"", .add)
    }

    func toggleDone(_ item: TodoItem) {
        guard let i = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[i].isDone.toggle()
        if selectedTodo == nil { selectedTodoID = orderedTodos.first { !$0.isDone }?.id }
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
        if selectedTodo == nil { selectedTodoID = orderedTodos.first { !$0.isDone }?.id }
        addLog("- removed \"\(item.title)\"", .info)
    }

    func clearDone() { todos.removeAll { $0.isDone } }

    // MARK: - Commands

    static let helpText = "start · pause · reset · skip · add <할 일> · done <#> · focus <#> · mode <m> · clear"

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
            if arg.isEmpty { fail("usage: add <할 일>") } else { addTodo(arg) }
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
        todos = s.todos
        settings = s.settings
        selectedTodoID = s.selectedTodoID
        todayDate = s.todayDate
        let isToday = Calendar.current.isDateInToday(s.todayDate)
        todayCount = isToday ? s.todayCount : 0
        // 예전 버전은 집중 시간을 따로 저장하지 않았으므로 개수 × 집중 시간으로 추정
        todayFocusMinutes = !isToday ? 0 : s.todayFocusMinutes > 0 ? s.todayFocusMinutes : s.todayCount * s.settings.focusMinutes
    }

    private func save() {
        guard !loading else { return }
        let s = SavedState(todos: todos, settings: settings, selectedTodoID: selectedTodoID,
                           todayCount: todayCount, todayFocusMinutes: todayFocusMinutes, todayDate: todayDate)
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
