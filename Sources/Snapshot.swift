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

        let store = AppStore.sample()
        render(MainWindowView().environmentObject(store), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main.png"))
        render(MainWindowView().environmentObject(store), size: CGSize(width: 640, height: 900),
               to: dir.appendingPathComponent("main-narrow.png"))

        let schedStore = AppStore.sample()
        schedStore.listTab = .scheduled
        schedStore.inlineAdd = .top
        render(MainWindowView().environmentObject(schedStore), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main-scheduled.png"))
        render(PeriodEditor(item: schedStore.orderedTodos[0]).environmentObject(schedStore),
               size: CGSize(width: 400, height: 280), to: dir.appendingPathComponent("period-editor.png"))

        let breakStore = AppStore.sample()
        breakStore.skip()
        render(MainWindowView().environmentObject(breakStore), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main-break.png"))

        render(MenuBarPopover().environmentObject(store).fixedSize(), size: CGSize(width: 320, height: 460),
               to: dir.appendingPathComponent("popover.png"))
        let pills = HStack(spacing: 12) {
            Image(nsImage: MenuBarLabel.image(time: "18:42", mode: .focus, running: true))
            Image(nsImage: MenuBarLabel.image(time: "05:00", mode: .shortBreak, running: true))
            Image(nsImage: MenuBarLabel.image(time: "25:00", mode: .focus, running: false))
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

    static func render<V: View>(_ view: V, size: CGSize, to url: URL) {
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
