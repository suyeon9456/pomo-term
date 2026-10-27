import AppKit
import Foundation
import UserNotifications

final class AppStore: ObservableObject {
    @Published var todos: [TodoItem] = [] { didSet { save() } }
    @Published var settings = AppSettings() { didSet { settingsChanged(oldValue) } }
    @Published var selectedTodoID: UUID? { didSet { save() } }
    @Published var todayCount = 0 { didSet { save() } }

    @Published private(set) var mode: TimerMode = .focus
    @Published private(set) var remaining: Int = 25 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var focusStreak = 0

    private var todayDate = Date()
    private var timer: Timer?
    private var endDate: Date?
    private var loading = false

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    init() {
        load()
        remaining = duration(for: mode)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Timer

    var totalSeconds: Int { duration(for: mode) }
    var progress: Double { totalSeconds == 0 ? 0 : 1 - Double(remaining) / Double(totalSeconds) }
    var timeString: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var selectedTodo: TodoItem? { todos.first { $0.id == selectedTodoID } }

    func duration(for mode: TimerMode) -> Int {
        switch mode {
        case .focus: return settings.focusMinutes * 60
        case .shortBreak: return settings.shortBreakMinutes * 60
        case .longBreak: return settings.longBreakMinutes * 60
        }
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remaining))
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        endDate = nil
    }

    func reset() {
        pause()
        remaining = duration(for: mode)
    }

    func skip() { advance(completed: false) }

    func switchMode(_ newMode: TimerMode) {
        pause()
        mode = newMode
        remaining = duration(for: newMode)
    }

    private func tick() {
        guard let endDate else { return }
        let left = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        if left != remaining { remaining = left }
        if left == 0 { advance(completed: true) }
    }

    private func advance(completed: Bool) {
        pause()
        let finished = mode
        if finished == .focus {
            if completed {
                rollDayIfNeeded()
                todayCount += 1
                if let id = selectedTodoID, let i = todos.firstIndex(where: { $0.id == id }) {
                    todos[i].completedPomodoros += 1
                }
            }
            focusStreak += 1
            mode = focusStreak % max(1, settings.longBreakInterval) == 0 ? .longBreak : .shortBreak
        } else {
            mode = .focus
        }
        remaining = duration(for: mode)
        if completed {
            notify(finished: finished)
            if settings.autoStartNext { start() }
        }
    }

    private func notify(finished: TimerMode) {
        if settings.playSound { NSSound(named: "Glass")?.play() }
        let content = UNMutableNotificationContent()
        content.title = finished == .focus ? "🍅 집중 완료!" : "휴식 끝!"
        content.body = finished == .focus
            ? "\(mode.label) 시간이에요. 잠깐 쉬어가세요."
            : "다시 집중할 시간이에요\(selectedTodo.map { ": \($0.title)" } ?? ".")"
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func rollDayIfNeeded() {
        if !Calendar.current.isDateInToday(todayDate) {
            todayDate = Date()
            todayCount = 0
        }
    }

    private func settingsChanged(_ old: AppSettings) {
        save()
        // 멈춰 있고 아직 시작 전인 타이머만 새 시간으로 맞춤
        if !isRunning && remaining == durationFor(mode, in: old) {
            remaining = duration(for: mode)
        }
    }

    private func durationFor(_ mode: TimerMode, in s: AppSettings) -> Int {
        switch mode {
        case .focus: return s.focusMinutes * 60
        case .shortBreak: return s.shortBreakMinutes * 60
        case .longBreak: return s.longBreakMinutes * 60
        }
    }

    // MARK: - Todos

    func addTodo(_ title: String, estimate: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed, estimatedPomodoros: estimate)
        todos.append(item)
        if selectedTodoID == nil { selectedTodoID = item.id }
    }

    func toggleDone(_ item: TodoItem) {
        guard let i = todos.firstIndex(of: item) else { return }
        todos[i].isDone.toggle()
        if todos[i].isDone && selectedTodoID == item.id {
            selectedTodoID = todos.first { !$0.isDone }?.id
        }
    }

    func delete(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
        if selectedTodoID == item.id { selectedTodoID = todos.first { !$0.isDone }?.id }
    }

    func clearDone() { todos.removeAll { $0.isDone } }

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
        todayCount = Calendar.current.isDateInToday(s.todayDate) ? s.todayCount : 0
    }

    private func save() {
        guard !loading else { return }
        let s = SavedState(todos: todos, settings: settings, selectedTodoID: selectedTodoID,
                           todayCount: todayCount, todayDate: todayDate)
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
