import AppKit
import SwiftUI

// MARK: - 이미지 (Resources/Images, Xcode 없이 빌드하므로 Asset Catalog 대신 번들 파일)

enum DogImages {
    private static var cache: [String: NSImage] = [:]

    static func image(_ file: String) -> NSImage {
        if let cached = cache[file] { return cached }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        let image = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Images")
            .flatMap(NSImage.init(contentsOf:)) ?? NSImage()
        cache[file] = image
        return image
    }
}

/// 원형으로 자른 강아지 얼굴 (사이드바 로고, 미니 타이머)
struct DogAvatar: View {
    let file: String
    let size: CGFloat
    var background: Color = .clear

    var body: some View {
        Image(nsImage: DogImages.image(file))
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - 아이콘 (dog-themes/icons/*.svg를 SwiftUI로, 24×24 좌표)

/// 발바닥. outline이면 테두리만
struct PawIcon: View {
    var fill: Color
    var stroke: Color? = nil
    var size: CGFloat = 16

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            let paw = Self.path
            ctx.fill(paw, with: .color(fill))
            if let stroke { ctx.stroke(paw, with: .color(stroke), lineWidth: 1.6) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static let path = Path { p in
        p.move(to: .init(x: 12, y: 13.5))
        p.addCurve(to: .init(x: 6.5, y: 18.3), control1: .init(x: 9, y: 13.5), control2: .init(x: 6.5, y: 16.1))
        p.addCurve(to: .init(x: 9.3, y: 20.5), control1: .init(x: 6.5, y: 19.9), control2: .init(x: 7.8, y: 20.5))
        p.addCurve(to: .init(x: 12, y: 20), control1: .init(x: 10.4, y: 20.5), control2: .init(x: 11.1, y: 20))
        p.addCurve(to: .init(x: 14.7, y: 20.5), control1: .init(x: 12.9, y: 20), control2: .init(x: 13.6, y: 20.5))
        p.addCurve(to: .init(x: 17.5, y: 18.3), control1: .init(x: 16.2, y: 20.5), control2: .init(x: 17.5, y: 19.9))
        p.addCurve(to: .init(x: 12, y: 13.5), control1: .init(x: 17.5, y: 16.1), control2: .init(x: 15, y: 13.5))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: 4, y: 7.9, width: 4, height: 5.2))
        p.addEllipse(in: CGRect(x: 7.4, y: 3.8, width: 4.2, height: 5.4))
        p.addEllipse(in: CGRect(x: 12.4, y: 3.8, width: 4.2, height: 5.4))
        p.addEllipse(in: CGRect(x: 16, y: 7.9, width: 4, height: 5.2))
    }
}

/// 골든: 테니스공 (채움 = 딴 뽀모도로, 빈 것 = 남은)
struct TennisBallIcon: View {
    var filled: Bool
    var size: CGFloat = 16

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            let ball = Path(ellipseIn: CGRect(x: 3, y: 3, width: 18, height: 18))
            ctx.fill(ball, with: .color(filled ? Color(hex: 0xD4E157) : .white))
            ctx.stroke(ball, with: .color(filled ? Color(hex: 0xA9B52E) : Color(hex: 0xD6C2A3)), lineWidth: 1.4)
            let seam = Path { p in
                p.move(to: .init(x: 5, y: 6.5)); p.addCurve(to: .init(x: 5, y: 17.5), control1: .init(x: 9, y: 9), control2: .init(x: 9, y: 15))
                p.move(to: .init(x: 19, y: 6.5)); p.addCurve(to: .init(x: 19, y: 17.5), control1: .init(x: 15, y: 9), control2: .init(x: 15, y: 15))
            }
            ctx.stroke(seam, with: .color(filled ? .white : Color(hex: 0xD6C2A3)),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 설이: 뼈다귀 간식 (채움 = 받은 간식, 빈 것 = 남은)
struct BoneIcon: View {
    var filled: Bool
    var size: CGFloat = 18

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            func bone(r: CGFloat, barY: CGFloat, barH: CGFloat) -> Path {
                Path { p in
                    for (x, y) in [(6.5, 9.5), (6.5, 14.5), (17.5, 9.5), (17.5, 14.5)] {
                        p.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    }
                    p.addRect(CGRect(x: 6.5, y: barY, width: 11, height: barH))
                }
            }
            ctx.fill(bone(r: 3.4, barY: 9.4, barH: 5.2), with: .color(filled ? Color(hex: 0xCDA67E) : Color(hex: 0xE2D3C6)))
            ctx.fill(bone(r: 2.6, barY: 10.2, barH: 3.6), with: .color(filled ? Color(hex: 0xE6CDAE) : .white))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 테마에 맞는 뽀모도로 개수 아이콘
struct TreatIcon: View {
    let treat: DogStyle.Treat
    let filled: Bool
    var size: CGFloat

    var body: some View {
        switch treat {
        case .tennisBall: TennisBallIcon(filled: filled, size: size)
        case .bone: BoneIcon(filled: filled, size: size)
        }
    }
}

/// 사이드바 아이콘
struct DogNavIcon: View {
    enum Kind { case sun, calendar, check, paw }
    let kind: Kind
    var color: Color

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            switch kind {
            case .sun:
                ctx.fill(Path(ellipseIn: CGRect(x: 7, y: 7, width: 10, height: 10)), with: .color(color))
                ctx.stroke(Path { p in
                    for (a, b) in [((12, 2), (12, 4.5)), ((12, 19.5), (12, 22)), ((4.9, 4.9), (6.7, 6.7)), ((17.3, 17.3), (19.1, 19.1)),
                                   ((2, 12), (4.5, 12)), ((19.5, 12), (22, 12)), ((4.9, 19.1), (6.7, 17.3)), ((17.3, 6.7), (19.1, 4.9))] {
                        p.move(to: CGPoint(x: a.0, y: a.1)); p.addLine(to: CGPoint(x: b.0, y: b.1))
                    }
                }, with: .color(color), style: style)
            case .calendar:
                ctx.stroke(Path(roundedRect: CGRect(x: 3, y: 5, width: 18, height: 16), cornerRadius: 4.5), with: .color(color), style: style)
                ctx.stroke(Path { p in
                    p.move(to: .init(x: 16, y: 3)); p.addLine(to: .init(x: 16, y: 7))
                    p.move(to: .init(x: 8, y: 3)); p.addLine(to: .init(x: 8, y: 7))
                    p.move(to: .init(x: 3, y: 11)); p.addLine(to: .init(x: 21, y: 11))
                }, with: .color(color), style: style)
            case .check:
                ctx.stroke(Path(ellipseIn: CGRect(x: 3, y: 3, width: 18, height: 18)), with: .color(color), style: style)
                ctx.stroke(Path { p in
                    p.move(to: .init(x: 8, y: 12.5)); p.addLine(to: .init(x: 11, y: 15.5)); p.addLine(to: .init(x: 16, y: 9.5))
                }, with: .color(color), style: style)
            case .paw:
                ctx.fill(PawIcon.path, with: .color(color))
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

// MARK: - 부드러운 카드 (테두리 없이 그림자)

extension View {
    /// 흰 카드 + 부드러운 그림자. 모서리는 .circular (알약 모양 테두리 문제와 맞춤)
    func dogCard(_ style: DogStyle, radius: CGFloat, fill: Color = .white, shadow: Double = 0.08,
                 shadowRadius: CGFloat = 10, y: CGFloat = 2) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .circular)
                .fill(fill)
                .shadow(color: style.shadow.opacity(shadow), radius: shadowRadius / 2, y: y)
        )
    }
}

/// 테두리 없는 둥근 버튼. 누르면 살짝 작아짐
struct DogButtonStyle: ButtonStyle {
    var fill: Color
    var radius: CGFloat
    var shadow: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: radius, style: .circular)
                    .fill(fill)
                    .shadow(color: shadow, radius: 5, y: 3)
            )
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .circular))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 원형 버전 (초기화 · 재생 · 건너뛰기)
struct DogCircleButtonStyle: ButtonStyle {
    var fill: Color
    var size: CGFloat
    var shadow: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(Circle().fill(fill).shadow(color: shadow, radius: 6, y: 3))
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 둥근 진행 바 (바탕 track, 채움 accent)
struct DogProgressBar: View {
    let fraction: Double
    let fill: Color
    let track: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .circular).fill(track)
                Capsule(style: .circular).fill(fill).frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
