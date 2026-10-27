import SwiftUI

/// 테마 선택. 로직(AppStore)은 하나이고 화면만 테마별로 다름 (theme-architecture.md)
enum ThemeID: String, CaseIterable, Identifiable {
    case terminal

    static let storageKey = "theme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal: return "터미널"
        }
    }
}

private struct ThemeIDKey: EnvironmentKey {
    static let defaultValue: ThemeID = .terminal
}

extension EnvironmentValues {
    var themeID: ThemeID {
        get { self[ThemeIDKey.self] }
        set { self[ThemeIDKey.self] = newValue }
    }
}

// MARK: - 테마별 화면으로 갈라지는 지점

struct MainWindowView: View {
    @Environment(\.themeID) private var themeID

    var body: some View {
        switch themeID {
        case .terminal: TerminalMainView()
        }
    }
}

struct MenuBarPopover: View {
    @Environment(\.themeID) private var themeID

    var body: some View {
        switch themeID {
        case .terminal: TerminalPopover()
        }
    }
}

/// 메뉴 막대 라벨. 항상 살아 있으므로 여기서 openWindow를 스토어에 연결
struct MenuBarLabel: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.themeID) private var themeID
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch themeID {
            case .terminal: TerminalMenuBarLabel()
            }
        }
        .onAppear {
            store.openMainWindow = {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

struct MiniTimerView: View {
    @Environment(\.themeID) private var themeID
    var onOpenMain: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        switch themeID {
        case .terminal: TerminalMiniTimer(onOpenMain: onOpenMain, onClose: onClose)
        }
    }
}
