import SwiftUI

/// 테마 선택. 로직(AppStore)은 하나이고 화면만 테마별로 다름 (theme-architecture.md)
enum ThemeID: String, CaseIterable, Identifiable {
    case terminal
    case cute
    case pom
    case golden

    static let storageKey = "theme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal: return "터미널"
        case .cute: return "토마토 친구"
        case .pom: return "설이"
        case .golden: return "골든 타임"
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

/// 터미널을 뺀 밝은 테마들이 설정 창·기간 시트에서 같이 쓰는 색
struct LightPalette {
    let text: Color
    let secondary: Color
    let window: Color
    let accent: Color
    /// 주 버튼 채움
    let primary: Color
    let error: Color
    let design: Font.Design
}

extension ThemeID {
    var light: LightPalette? {
        if self == .cute {
            return LightPalette(text: .cute.ink, secondary: .cute.inkSecondary, window: .cute.window, accent: .cute.tomato,
                                primary: .cute.butter, error: .cute.link, design: .default)
        }
        if let dog = DogStyle.of(self) {
            return LightPalette(text: dog.text, secondary: dog.textSecondary, window: dog.window, accent: dog.focusAccent,
                                primary: dog.focusAccent, error: dog.strong, design: .rounded)
        }
        return nil
    }
}

extension ListTab {
    /// ⌘1 / ⌘2 / ⌘3 (모든 테마 공통)
    var shortcutKey: KeyEquivalent {
        switch self {
        case .today: return "1"
        case .scheduled: return "2"
        case .done: return "3"
        }
    }

    var accessibilityName: String {
        switch self {
        case .today: return "오늘 할 일"
        case .scheduled: return "기간 할 일"
        case .done: return "완료함"
        }
    }
}

// MARK: - 테마별 화면으로 갈라지는 지점

struct MainWindowView: View {
    @Environment(\.themeID) private var themeID

    var body: some View {
        switch themeID {
        case .terminal: TerminalMainView()
        case .cute: CuteMainView()
        case .pom: DogMainView(style: .seol)
        case .golden: DogMainView(style: .golden)
        }
    }
}

struct MenuBarPopover: View {
    @Environment(\.themeID) private var themeID

    var body: some View {
        switch themeID {
        case .terminal: TerminalPopover()
        case .cute: CutePopover()
        case .pom, .golden: DogPopover(style: DogStyle.of(themeID) ?? .seol)
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
            case .cute: CuteMenuBarLabel()
            case .pom, .golden: DogMenuBarLabel(style: DogStyle.of(themeID) ?? .seol)
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
        case .cute: CuteMiniTimer(onOpenMain: onOpenMain, onClose: onClose)
        case .pom, .golden: DogMiniTimer(style: DogStyle.of(themeID) ?? .seol, onOpenMain: onOpenMain, onClose: onClose)
        }
    }
}
