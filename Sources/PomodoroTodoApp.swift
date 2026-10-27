import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let dir = Snapshot.outputDirectory {
            Snapshot.run(to: dir)
            exit(0)
        }
    }
}

@main
struct PomodoroTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore(persistent: Snapshot.outputDirectory == nil)

    var body: some Scene {
        Window("pomo", id: "main") {
            MainWindowView().environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 760)

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
