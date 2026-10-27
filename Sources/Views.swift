import SwiftUI

extension TimerMode {
    var color: Color {
        switch self {
        case .focus: return Color(red: 0.91, green: 0.33, blue: 0.29)
        case .shortBreak: return Color(red: 0.22, green: 0.62, blue: 0.56)
        case .longBreak: return Color(red: 0.30, green: 0.48, blue: 0.80)
        }
    }
}

// MARK: - Menu bar

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("\(store.mode.emoji) \(store.mode.label) · \(store.timeString)")
        if let todo = store.selectedTodo { Text("작업: \(todo.title)") }
        Divider()
        Button(store.isRunning ? "일시정지" : "시작", action: store.toggle)
        Button("건너뛰기", action: store.skip)
        Button("초기화", action: store.reset)
        Divider()
        Button("창 열기") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("종료") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Form {
            Stepper("집중: \(store.settings.focusMinutes)분", value: $store.settings.focusMinutes, in: 1...120)
            Stepper("짧은 휴식: \(store.settings.shortBreakMinutes)분", value: $store.settings.shortBreakMinutes, in: 1...60)
            Stepper("긴 휴식: \(store.settings.longBreakMinutes)분", value: $store.settings.longBreakMinutes, in: 1...90)
            Stepper("긴 휴식 간격: 뽀모도로 \(store.settings.longBreakInterval)회마다",
                    value: $store.settings.longBreakInterval, in: 2...10)
            Toggle("다음 타이머 자동 시작", isOn: $store.settings.autoStartNext)
            Toggle("완료 시 소리 재생", isOn: $store.settings.playSound)
        }
        .padding(20)
        .frame(width: 360)
    }
}
