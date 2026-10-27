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
    /// 기간 할 일이면 마감일이 있음. 시작일은 선택
    var startDate: Date?
    var dueDate: Date?
    /// 완료한 날이 지나면 목록에서 숨기기 위해 기록
    var completedAt: Date?
    /// 이 할 일만의 집중 시간(분). nil이면 기본 집중 시간
    var focusMinutes: Int?
    /// 하위 태스크면 상위 스토리의 id (스토리 > 태스크 두 단계까지만)
    var parentID: UUID?
    /// 스토리의 하위 태스크 접기
    var isCollapsed = false
    var createdAt = Date()

    var isScheduled: Bool { dueDate != nil }

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
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes)
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        isCollapsed = try c.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// 목록 한 줄. 스토리는 depth 0, 그 아래 태스크는 depth 1. number는 "1", "1.2"
struct ListRow: Identifiable {
    let number: String
    let item: TodoItem
    let depth: Int
    /// 스토리의 마지막 하위 태스크인지 (├ / └ 표시용)
    var isLastChild = false
    var id: UUID { item.id }
}

/// 목록 안에서 바로 입력하는 줄: 맨 아래 할 일 추가, 또는 스토리 아래 태스크 추가
enum InlineAdd: Equatable {
    case top
    case sub(UUID)
}

enum ListTab: String, CaseIterable {
    case today, scheduled

    var fileName: String { "\(rawValue).md" }
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
    var globalHotKey = true

    init() {}

    // 새 설정이 추가돼도 예전 data.json의 설정이 그대로 읽히도록 빠진 키는 기본값
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        longBreakInterval = try c.decodeIfPresent(Int.self, forKey: .longBreakInterval) ?? d.longBreakInterval
        autoStartNext = try c.decodeIfPresent(Bool.self, forKey: .autoStartNext) ?? d.autoStartNext
        playSound = try c.decodeIfPresent(Bool.self, forKey: .playSound) ?? d.playSound
        globalHotKey = try c.decodeIfPresent(Bool.self, forKey: .globalHotKey) ?? d.globalHotKey
    }
}

struct SavedState: Codable {
    var todos: [TodoItem] = []
    var settings = AppSettings()
    var selectedTodoID: UUID?
    var todayCount = 0
    var todayFocusMinutes = 0
    var todayBreakCount = 0
    var todayBreakMinutes = 0
    var todayDate = Date()

    init(todos: [TodoItem], settings: AppSettings, selectedTodoID: UUID?,
         todayCount: Int, todayFocusMinutes: Int, todayBreakCount: Int, todayBreakMinutes: Int, todayDate: Date) {
        self.todos = todos
        self.settings = settings
        self.selectedTodoID = selectedTodoID
        self.todayCount = todayCount
        self.todayFocusMinutes = todayFocusMinutes
        self.todayBreakCount = todayBreakCount
        self.todayBreakMinutes = todayBreakMinutes
        self.todayDate = todayDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        todos = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        selectedTodoID = try c.decodeIfPresent(UUID.self, forKey: .selectedTodoID)
        todayCount = try c.decodeIfPresent(Int.self, forKey: .todayCount) ?? 0
        todayFocusMinutes = try c.decodeIfPresent(Int.self, forKey: .todayFocusMinutes) ?? 0
        todayBreakCount = try c.decodeIfPresent(Int.self, forKey: .todayBreakCount) ?? 0
        todayBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .todayBreakMinutes) ?? 0
        todayDate = try c.decodeIfPresent(Date.self, forKey: .todayDate) ?? Date()
    }
}
