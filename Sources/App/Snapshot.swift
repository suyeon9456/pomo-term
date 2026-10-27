import AppKit
import SwiftUI

/// 개발용: `PomodoroTodo --snapshot <폴더>`로 실행하면 각 화면을 샘플 데이터로 PNG 렌더링하고 종료.
/// 화면 녹화 권한 없이 시안과 비교하기 위한 도구. data.json은 건드리지 않음.
@MainActor
enum Snapshot {
    nonisolated static var outputDirectory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }

    static func run(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        renderCuteParts(to: dir.appendingPathComponent("cute-parts.png"))

        let store = AppStore.sample()
        let renameStore = AppStore.sample()
        renameStore.renamingID = renameStore.orderedTodos[1].id
        render(MainWindowView().environmentObject(renameStore), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main-rename.png"))
        render(MainWindowView().environmentObject(store), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main.png"))
        render(MainWindowView().environmentObject(store), size: CGSize(width: 640, height: 900),
               to: dir.appendingPathComponent("main-narrow.png"))

        // 귀여운 테마 메인 창
        let cute = { (v: AnyView) in v.environment(\.themeID, .cute) }
        render(cute(AnyView(MainWindowView().environmentObject(store))), size: CGSize(width: 1280, height: 860),
               to: dir.appendingPathComponent("cute-main.png"))
        let cuteBreak = AppStore.sample()
        cuteBreak.skip()
        render(cute(AnyView(MainWindowView().environmentObject(cuteBreak))), size: CGSize(width: 1280, height: 860),
               to: dir.appendingPathComponent("cute-main-break.png"))
        let cuteSched = AppStore.sample()
        cuteSched.listTab = .scheduled
        if let story = cuteSched.todos.first(where: { cuteSched.hasChildren($0) }) { cuteSched.inlineAdd = .sub(story.id) }
        TaskRowDebug.alwaysShowActions = true
        render(cute(AnyView(MainWindowView().environmentObject(cuteSched))), size: CGSize(width: 1280, height: 860),
               to: dir.appendingPathComponent("cute-main-scheduled.png"))
        TaskRowDebug.alwaysShowActions = false
        render(cute(AnyView(MainWindowView().environmentObject(store))), size: CGSize(width: 820, height: 1000),
               to: dir.appendingPathComponent("cute-main-narrow.png"))

        render(cute(AnyView(MenuBarPopover().environmentObject(store).fixedSize())), size: CGSize(width: 320, height: 600),
               to: dir.appendingPathComponent("cute-popover.png"))
        let cutePills = VStack(spacing: 10) {
            ForEach([Color(hex: 0xF4EEE9), Color(hex: 0x2B2B2B)], id: \.self) { bar in
                HStack(spacing: 12) {
                    Image(nsImage: CuteMenuBarLabel.image(time: "18:42", mode: .focus, running: true))
                    Image(nsImage: CuteMenuBarLabel.image(time: "05:00", mode: .shortBreak, running: true))
                    Image(nsImage: CuteMenuBarLabel.image(time: "25:00", mode: .focus, running: false))
                }
                .padding(8)
                .background(bar)
            }
        }
        render(cutePills, size: CGSize(width: 320, height: 90), to: dir.appendingPathComponent("cute-menubar-label.png"))

        let cuteMinis = VStack(spacing: 16) {
            MiniTimerView().environmentObject(store)
            MiniTimerView().environmentObject(cuteBreak)
        }
        .padding(20)
        .background(Color(hex: 0xFCE3D6))
        render(cute(AnyView(cuteMinis)), size: CGSize(width: 360, height: 270), to: dir.appendingPathComponent("cute-mini.png"))

        // 설정 창은 @AppStorage로 테마를 읽으므로 잠깐 바꿨다가 사용자가 고른 값으로 되돌림
        let savedTheme = UserDefaults.standard.string(forKey: ThemeID.storageKey)
        for theme in ThemeID.allCases {
            UserDefaults.standard.set(theme.rawValue, forKey: ThemeID.storageKey)
            render(SettingsView().environmentObject(store).fixedSize(), size: CGSize(width: 480, height: 560),
                   to: dir.appendingPathComponent("settings-\(theme.rawValue).png"))
        }
        if let savedTheme {
            UserDefaults.standard.set(savedTheme, forKey: ThemeID.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ThemeID.storageKey)
        }

        let schedStore = AppStore.sample()
        schedStore.listTab = .scheduled
        render(MainWindowView().environmentObject(schedStore), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main-scheduled.png"))

        // 스토리 아래 태스크 입력줄과 마우스 오버 버튼까지 보이게
        if let story = schedStore.todos.first(where: { schedStore.hasChildren($0) }) { schedStore.inlineAdd = .sub(story.id) }
        TaskRowDebug.alwaysShowActions = true
        render(MainWindowView().environmentObject(schedStore), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main-actions.png"))
        TaskRowDebug.alwaysShowActions = false
        render(PeriodEditor(item: schedStore.orderedTodos[0]).environmentObject(schedStore),
               size: CGSize(width: 400, height: 280), to: dir.appendingPathComponent("period-editor.png"))

        let breakStore = AppStore.sample()
        breakStore.skip()
        render(MainWindowView().environmentObject(breakStore), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main-break.png"))

        render(MenuBarPopover().environmentObject(store).fixedSize(), size: CGSize(width: 320, height: 460),
               to: dir.appendingPathComponent("popover.png"))
        let pills = HStack(spacing: 12) {
            Image(nsImage: TerminalMenuBarLabel.image(time: "18:42", mode: .focus, running: true))
            Image(nsImage: TerminalMenuBarLabel.image(time: "05:00", mode: .shortBreak, running: true))
            Image(nsImage: TerminalMenuBarLabel.image(time: "25:00", mode: .focus, running: false))
        }
        .padding(8)
        .background(Color(hex: 0x141717))
        render(pills, size: CGSize(width: 320, height: 40), to: dir.appendingPathComponent("menubar-label.png"))

        let minis = VStack(spacing: 12) {
            MiniTimerView().environmentObject(store)
            MiniTimerView().environmentObject(breakStore)
        }
        .padding(20)
        .background(Color(hex: 0x262B2A))
        render(minis, size: CGSize(width: 360, height: 244), to: dir.appendingPathComponent("mini.png"))
    }

    /// 귀여운 테마 부품 모음 (캐릭터 표정, 아이콘, 링, 말풍선, 버튼)
    static func renderCuteParts(to url: URL) {
        let parts = VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 24) {
                ForEach([TomatoMood.idle, .focus, .rest], id: \.self) { TomatoMascot(mood: $0, size: 170) }
                VStack(spacing: 12) {
                    TomatoMascot(mood: .focus, size: 76, lineScale: 1.4)
                    TomatoMascot(mood: .focus, size: 44, lineScale: 2, simple: true)
                    TomatoMascot(mood: .idle, size: 40, lineScale: 2, simple: true)
                }
            }
            HStack(spacing: 8) {
                ForEach([TomatoIconStyle.filled, .empty, .current, .upcoming], id: \.self) { TomatoIcon(style: $0, size: 22) }
                ProjectChip(project: .work); ProjectChip(project: .personal); ProjectChip(project: .study)
                CuteProgressBar(fraction: 0.33).frame(width: 200)
            }
            HStack(spacing: 28) {
                ZStack {
                    CuteRing(progress: 0.25, mode: .focus, diameter: 232, lineWidth: 16, outlined: true)
                    TomatoMascot(mood: .focus, size: 170)
                }
                .frame(width: 260, height: 260)
                CuteRing(progress: 0.6, mode: .shortBreak, diameter: 62, lineWidth: 7)
                VStack(spacing: 20) {
                    SpeechBubble(text: "쉿, 집중 중이야… 19분만 더!")
                    HStack(spacing: 22) {
                        Button {} label: { Image(systemName: "arrow.counterclockwise").font(.system(size: 20, weight: .bold)) }
                            .buttonStyle(CuteCircleButtonStyle(size: 50))
                        Button {} label: { CutePlayIcon(size: 32).offset(x: 2) }
                            .buttonStyle(CuteCircleButtonStyle(fill: TimerMode.focus.cuteAccent, size: 78, shadow: 5, lineWidth: 2.5))
                        Button {} label: { CutePauseIcon(size: 28) }
                            .buttonStyle(CuteCircleButtonStyle(fill: TimerMode.shortBreak.cuteAccent, size: 78, shadow: 5, lineWidth: 2.5))
                    }
                    Button {} label: { Text("추가").font(.system(size: 15, weight: .semibold)).padding(.horizontal, 18).frame(height: 38) }
                        .buttonStyle(CuteButtonStyle(fill: .cute.butter, radius: 12))
                }
            }
        }
        .padding(30)
        .background(Color.cute.window)
        render(parts, size: CGSize(width: 900, height: 620), to: url)
    }

    /// SNAPSHOT_RENDERER=image 이면 ImageRenderer로 (실험)
    static func render<V: View>(_ view: V, size: CGSize, to url: URL) {
        if ProcessInfo.processInfo.environment["SNAPSHOT_RENDERER"] == "image" {
            let r = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
            return
        }
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.close()
    }
}
