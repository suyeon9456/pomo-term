import Foundation

enum Project: String, Codable, CaseIterable {
    case work = "업무"
    case personal = "개인"
    case study = "공부"
}

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isDone = false
    var estimatedPomodoros = 1
    var completedPomodoros = 0
    var project: Project = .work
    var createdAt = Date()

    init(title: String, estimatedPomodoros: Int = 1, project: Project = .work) {
        self.title = title
        self.estimatedPomodoros = estimatedPomodoros
        self.project = project
    }

    // 예전 data.json에는 project가 없으므로 빠진 키는 기본값으로 채움
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        estimatedPomodoros = try c.decodeIfPresent(Int.self, forKey: .estimatedPomodoros) ?? 1
        completedPomodoros = try c.decodeIfPresent(Int.self, forKey: .completedPomodoros) ?? 0
        project = try c.decodeIfPresent(Project.self, forKey: .project) ?? .work
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

enum TimerMode: String, Codable, CaseIterable {
    case focus, shortBreak, longBreak

    var label: String {
        switch self {
        case .focus: return "집중"
        case .shortBreak: return "짧은 휴식"
        case .longBreak: return "긴 휴식"
        }
    }

    var emoji: String {
        switch self {
        case .focus: return "🍅"
        case .shortBreak: return "☕️"
        case .longBreak: return "🌿"
        }
    }
}

struct LogEntry: Identifiable {
    enum Kind { case plain, info, success, warn, error, add, echo }

    let id = UUID()
    let time = Date()
    let text: String
    let kind: Kind
}

struct AppSettings: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var longBreakInterval = 4
    var autoStartNext = false
    var playSound = true
}

struct SavedState: Codable {
    var todos: [TodoItem] = []
    var settings = AppSettings()
    var selectedTodoID: UUID?
    var todayCount = 0
    var todayFocusMinutes = 0
    var todayDate = Date()

    init(todos: [TodoItem], settings: AppSettings, selectedTodoID: UUID?,
         todayCount: Int, todayFocusMinutes: Int, todayDate: Date) {
        self.todos = todos
        self.settings = settings
        self.selectedTodoID = selectedTodoID
        self.todayCount = todayCount
        self.todayFocusMinutes = todayFocusMinutes
        self.todayDate = todayDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        todos = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        selectedTodoID = try c.decodeIfPresent(UUID.self, forKey: .selectedTodoID)
        todayCount = try c.decodeIfPresent(Int.self, forKey: .todayCount) ?? 0
        todayFocusMinutes = try c.decodeIfPresent(Int.self, forKey: .todayFocusMinutes) ?? 0
        todayDate = try c.decodeIfPresent(Date.self, forKey: .todayDate) ?? Date()
    }
}
