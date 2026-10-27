import SwiftUI

@main
struct PomodoroTodoApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        Window("뽀모도로 할 일", id: "main") {
            ContentView().environmentObject(store)
        }
        .defaultSize(width: 760, height: 520)

        MenuBarExtra {
            MenuBarView().environmentObject(store)
        } label: {
            if store.isRunning {
                Text("\(store.mode.emoji) \(store.timeString)")
            } else {
                Image(systemName: "timer")
            }
        }

        Settings {
            SettingsView().environmentObject(store)
        }
    }
}
