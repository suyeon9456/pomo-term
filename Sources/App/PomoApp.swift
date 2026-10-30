import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let dir = Snapshot.iconDirectory {
            AppIconArt.renderIconset(to: dir)
            exit(0)
        }
        if let dir = Snapshot.outputDirectory {
            Snapshot.run(to: dir)
            exit(0)
        }
    }
}

@main
struct PomoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AppStore
    @AppStorage(ThemeID.storageKey) private var themeID: ThemeID = .terminal

    init() {
        // 설정을 읽기 전에 예전 번들 ID의 설정을 옮겨 옴 (스냅샷 모드는 건드리지 않음)
        if !Snapshot.isDevRun { LegacyMigration.run() }
        let store = AppStore(persistent: !Snapshot.isDevRun)
        store.toggleMiniTimer = { MiniTimerController.shared.toggle(store: store) }
        if !Snapshot.isDevRun { GlobalHotKey.shared.bind(to: store) }
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
