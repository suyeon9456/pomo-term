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
    @StateObject private var store: AppStore
    @AppStorage(ThemeID.storageKey) private var themeID: ThemeID = .terminal

    init() {
        let store = AppStore(persistent: Snapshot.outputDirectory == nil)
        store.toggleMiniTimer = { MiniTimerController.shared.toggle(store: store) }
        if Snapshot.outputDirectory == nil { GlobalHotKey.shared.bind(to: store) }
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        Window("pomo", id: "main") {
            MainWindowView().environmentObject(store).environment(\.themeID, themeID)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 할 일") { store.beginAdd(.top) }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .windowArrangement) {
                Button("미니 타이머") { store.toggleMiniTimer?() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarPopover().environmentObject(store).environment(\.themeID, themeID)
        } label: {
            MenuBarLabel().environmentObject(store).environment(\.themeID, themeID)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(store).environment(\.themeID, themeID)
        }
    }
}
