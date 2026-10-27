import AppKit
import SwiftUI

/// 개발용: `PomodoroTodo --snapshot <폴더>`로 실행하면 각 화면을 샘플 데이터로 PNG 렌더링하고 종료.
/// 화면 녹화 권한 없이 시안과 비교하기 위한 도구. data.json은 건드리지 않음.
enum Snapshot {
    static var outputDirectory: URL? {
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

        let breakStore = AppStore.sample()
        breakStore.skip()
        render(MainWindowView().environmentObject(breakStore), size: CGSize(width: 1280, height: 840),
               to: dir.appendingPathComponent("main-break.png"))
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
