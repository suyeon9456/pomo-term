import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isDone = false
    var estimatedPomodoros = 1
    var completedPomodoros = 0
    var createdAt = Date()
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
    var todayDate = Date()
}
