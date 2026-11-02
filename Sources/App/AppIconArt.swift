import AppKit
import SwiftUI

/// 앱 아이콘 (터미널 스타일). 1024×1024 기준으로 그리고 크기별로 렌더링해서 AppIcon.icns를 만듦
/// scripts/make-icon.sh → `Pomo --icon <폴더>`
struct AppIconArt: View {
    /// 16·32px처럼 아주 작을 때는 점·진행 바를 빼고 숫자만 크게
    var simple = false

    var body: some View {
        ZStack {
            // macOS 아이콘 격자: 1024 안에 824 크기의 둥근 사각형
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1C2121), Color.term.window], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 6))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 12)
                .frame(width: 824, height: 824)

            if simple {
                Text("25")
                    .font(.term(430, .extraBold))
                    .tracking(-20)
                    .foregroundStyle(Color.term.accentFocus)
                    .shadow(color: Color.term.accentFocus.opacity(0.35), radius: 24)
            } else {
                VStack(spacing: 0) {
                    // 타이틀바와 신호등
                    HStack(spacing: 26) {
                        ForEach([0xFF5F57, 0xFEBC2E, 0x28C840], id: \.self) { c in
                            Circle().fill(Color(hex: UInt32(c))).frame(width: 46, height: 46)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 70)
                    .frame(height: 140)
                    .background(Color.term.titlebar)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.term.border).frame(height: 6) }

                    Spacer(minLength: 0)
                    Text("❯ pomo")
                        .font(.term(76, .bold))
                        .foregroundStyle(Color.term.accentFocus.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 84)
                    Text("25:00")
                        .font(.term(250, .extraBold))
                        .tracking(-12)
                        .foregroundStyle(Color.term.accentFocus)
                        .shadow(color: Color.term.accentFocus.opacity(0.35), radius: 22)
                    HStack(spacing: 10) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 6, style: .circular)
                                .fill(i < 4 ? Color.term.accentFocus : Color.term.border)
                                .frame(width: 50, height: 44)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 824, height: 824)
                .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
            }
        }
        .frame(width: 1024, height: 1024)
    }

    /// iconset에 들어갈 (파일 이름, 픽셀 크기)
    static let iconsetSizes: [(String, Int)] = [16, 32, 128, 256, 512].flatMap { pt in
        [("icon_\(pt)x\(pt).png", pt), ("icon_\(pt)x\(pt)@2x.png", pt * 2)]
    }

    @MainActor
    static func renderIconset(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (file, px) in iconsetSizes {
            let renderer = ImageRenderer(content: AppIconArt(simple: px <= 32))
            renderer.scale = CGFloat(px) / 1024
            guard let cg = renderer.cgImage else { continue }
            let rep = NSBitmapImageRep(cgImage: cg)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(file))
        }
    }
}
