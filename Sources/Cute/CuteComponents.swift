import SwiftUI

// MARK: - 토마토 캐릭터 (assets/tomato-*.svg를 SwiftUI로 옮김, 200×200 좌표)

enum TomatoMood {
    case idle, focus, rest

    var accessibilityLabel: String {
        switch self {
        case .idle: return "웃고 있는 토마토"
        case .focus: return "집중하는 토마토"
        case .rest: return "쉬고 있는 토마토"
        }
    }

    static func of(mode: TimerMode, running: Bool) -> TomatoMood {
        mode != .focus ? .rest : running ? .focus : .idle
    }
}

struct TomatoMascot: View {
    let mood: TomatoMood
    var size: CGFloat
    /// 작게 그릴 때 선이 너무 가늘어지지 않게 굵기를 키움 (미니 타이머 2배, 팝오버 1.4배)
    var lineScale: CGFloat = 1
    /// 아주 작을 때는 바닥 그림자와 하이라이트를 뺌
    var simple = false

    var body: some View {
        Canvas { ctx, canvasSize in
            ctx.scaleBy(x: canvasSize.width / 200, y: canvasSize.height / 200)
            let ink = GraphicsContext.Shading.color(.cute.ink)
            func stroke(_ path: Path, _ width: CGFloat) {
                ctx.stroke(path, with: ink, style: StrokeStyle(lineWidth: width * lineScale, lineCap: .round, lineJoin: .round))
            }
            func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
            }

            if !simple {
                ctx.fill(ellipse(100, 188, 54, 7), with: .color(Color.cute.ink.opacity(0.12)))
            }
            let body = Self.bodyPath
            ctx.fill(body, with: .color(.cute.tomato))
            stroke(body, 5)
            if !simple {
                var hl = ctx
                hl.translateBy(x: 60, y: 92)
                hl.rotate(by: .degrees(-35))
                hl.fill(ellipse(0, 0, 14, 8), with: .color(Color.white.opacity(0.6)))
            }
            ctx.fill(Self.leafPath, with: .color(.cute.leaf))
            stroke(Self.leafPath, 5)
            stroke(Path { p in p.move(to: .init(x: 100, y: 52)); p.addCurve(to: .init(x: 112, y: 30), control1: .init(x: 100, y: 42), control2: .init(x: 104, y: 34)) }, 5)
            ctx.fill(ellipse(60, 140, 12, 7), with: .color(.cute.blush))
            ctx.fill(ellipse(140, 140, 12, 7), with: .color(.cute.blush))

            switch mood {
            case .idle, .focus:
                ctx.fill(ellipse(78, 122, 8, 10), with: ink)
                ctx.fill(ellipse(122, 122, 8, 10), with: ink)
                if !simple {
                    ctx.fill(ellipse(80.5, 118, 3, 3), with: .color(.white))
                    ctx.fill(ellipse(124.5, 118, 3, 3), with: .color(.white))
                }
                if mood == .idle {
                    stroke(Path { p in p.move(to: .init(x: 90, y: 138)); p.addQuadCurve(to: .init(x: 110, y: 138), control: .init(x: 100, y: 150)) }, 5)
                } else {
                    stroke(Path { p in p.move(to: .init(x: 66, y: 104)); p.addLine(to: .init(x: 86, y: 110)) }, 5)
                    stroke(Path { p in p.move(to: .init(x: 134, y: 104)); p.addLine(to: .init(x: 114, y: 110)) }, 5)
                    stroke(Path { p in p.move(to: .init(x: 92, y: 142)); p.addLine(to: .init(x: 108, y: 142)) }, 5)
                }
            case .rest:
                stroke(Path { p in p.move(to: .init(x: 68, y: 124)); p.addQuadCurve(to: .init(x: 88, y: 124), control: .init(x: 78, y: 114)) }, 5)
                stroke(Path { p in p.move(to: .init(x: 112, y: 124)); p.addQuadCurve(to: .init(x: 132, y: 124), control: .init(x: 122, y: 114)) }, 5)
                let mouth = Path { p in
                    p.move(to: .init(x: 88, y: 138)); p.addQuadCurve(to: .init(x: 112, y: 138), control: .init(x: 100, y: 156)); p.closeSubpath()
                }
                ctx.fill(mouth, with: ink)
                stroke(mouth, 4)
                if !simple {
                    stroke(Path { p in
                        p.move(to: .init(x: 146, y: 58)); p.addLine(to: .init(x: 158, y: 58))
                        p.addLine(to: .init(x: 146, y: 72)); p.addLine(to: .init(x: 158, y: 72))
                    }, 3.5)
                    stroke(Path { p in
                        p.move(to: .init(x: 164, y: 40)); p.addLine(to: .init(x: 173, y: 40))
                        p.addLine(to: .init(x: 164, y: 50)); p.addLine(to: .init(x: 173, y: 50))
                    }, 3)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(mood.accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    private static let bodyPath = Path { p in
        p.move(to: .init(x: 100, y: 48))
        p.addCurve(to: .init(x: 178, y: 122), control1: .init(x: 150, y: 44), control2: .init(x: 182, y: 80))
        p.addCurve(to: .init(x: 100, y: 184), control1: .init(x: 174, y: 164), control2: .init(x: 140, y: 184))
        p.addCurve(to: .init(x: 22, y: 122), control1: .init(x: 60, y: 184), control2: .init(x: 26, y: 164))
        p.addCurve(to: .init(x: 100, y: 48), control1: .init(x: 18, y: 80), control2: .init(x: 50, y: 44))
        p.closeSubpath()
    }

    private static let leafPath = Path { p in
        p.move(to: .init(x: 100, y: 52))
        p.addCurve(to: .init(x: 66, y: 44), control1: .init(x: 90, y: 40), control2: .init(x: 76, y: 38))
        p.addCurve(to: .init(x: 88, y: 56), control1: .init(x: 78, y: 48), control2: .init(x: 84, y: 52))
        p.addCurve(to: .init(x: 70, y: 74), control1: .init(x: 78, y: 60), control2: .init(x: 72, y: 66))
        p.addCurve(to: .init(x: 100, y: 60), control1: .init(x: 82, y: 68), control2: .init(x: 92, y: 62))
        p.addCurve(to: .init(x: 130, y: 74), control1: .init(x: 108, y: 62), control2: .init(x: 118, y: 68))
        p.addCurve(to: .init(x: 112, y: 56), control1: .init(x: 128, y: 66), control2: .init(x: 122, y: 60))
        p.addCurve(to: .init(x: 134, y: 44), control1: .init(x: 116, y: 52), control2: .init(x: 122, y: 48))
        p.addCurve(to: .init(x: 100, y: 52), control1: .init(x: 124, y: 38), control2: .init(x: 110, y: 40))
        p.closeSubpath()
    }
}

// MARK: - 토마토 아이콘 (뽀모도로 개수·세션 표시, 24×24 좌표)

enum TomatoIconStyle {
    /// 딴 토마토
    case filled
    /// 아직 안 딴 토마토 (할 일 카드)
    case empty
    /// 지금 키우는 세션
    case current
    /// 남은 세션
    case upcoming

    fileprivate var colors: (body: Color, leaf: Color, stroke: Color) {
        switch self {
        case .filled: return (.cute.tomato, .cute.leaf, .cute.ink)
        case .empty: return (.white, .white, .cute.emptyIcon)
        case .current: return (.cute.peach, .cute.mint, .cute.ink)
        case .upcoming: return (.white, .white, .cute.ink)
        }
    }
}

struct TomatoIcon: View {
    let style: TomatoIconStyle
    var size: CGFloat = 16

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            let c = style.colors
            let body = Path(ellipseIn: CGRect(x: 12 - 8.5, y: 14 - 8.5, width: 17, height: 17))
            ctx.fill(body, with: .color(c.body))
            ctx.stroke(body, with: .color(c.stroke), lineWidth: 1.8)
            let leaf = Path { p in
                p.move(to: .init(x: 12, y: 6.5)); p.addLine(to: .init(x: 9, y: 4.5)); p.addLine(to: .init(x: 11, y: 7))
                p.addLine(to: .init(x: 8, y: 8)); p.addLine(to: .init(x: 16, y: 8)); p.addLine(to: .init(x: 13, y: 7))
                p.addLine(to: .init(x: 15, y: 4.5)); p.closeSubpath()
            }
            ctx.fill(leaf, with: .color(c.leaf))
            ctx.stroke(leaf, with: .color(c.stroke), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 링, 말풍선, 아이콘

/// 진행 링. outlined면 바깥·안쪽에 ink 선을 둘러 튜브처럼 보임 (메인 창)
struct CuteRing: View {
    let progress: Double
    let mode: TimerMode
    var diameter: CGFloat
    var lineWidth: CGFloat
    var outlined = false

    var body: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: diameter, height: diameter)
            Circle().stroke(mode.cuteTrack, lineWidth: lineWidth).frame(width: diameter, height: diameter)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(mode.cuteAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .animation(.linear(duration: 0.25), value: progress)
            if outlined {
                Circle().stroke(Color.cute.ink, lineWidth: 2.5).frame(width: diameter + lineWidth + 2, height: diameter + lineWidth + 2)
                Circle().stroke(Color.cute.ink, lineWidth: 2.5).frame(width: diameter - lineWidth - 2, height: diameter - lineWidth - 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 아래 가운데 꼬리가 달린 말풍선
struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.cute.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white)
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cute.ink, lineWidth: 2)
                    // 꼬리: 45° 돌린 사각형의 오른쪽·아래 테두리만
                    BubbleTail()
                        .fill(Color.white)
                        .overlay(BubbleTail(edgesOnly: true).stroke(Color.cute.ink, style: StrokeStyle(lineWidth: 2, lineJoin: .round)))
                        .frame(width: 16, height: 9)
                        .offset(y: 7.5)
                }
            }
            .accessibilityLabel(text)
    }
}

private struct BubbleTail: Shape {
    var edgesOnly = false

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            if !edgesOnly { p.closeSubpath() }
        }
    }
}

/// 흰 재생 아이콘 + ink 외곽선 (휴식 accent 위에서도 대비 확보)
struct CutePlayIcon: View {
    var size: CGFloat

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            let p = Path { p in
                p.move(to: .init(x: 7, y: 4.5)); p.addLine(to: .init(x: 7, y: 19.5)); p.addLine(to: .init(x: 20, y: 12)); p.closeSubpath()
            }
            ctx.fill(p, with: .color(.white))
            ctx.stroke(p, with: .color(.cute.ink), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct CutePauseIcon: View {
    var size: CGFloat
    var fill: Color = .white

    var body: some View {
        Canvas { ctx, s in
            ctx.scaleBy(x: s.width / 24, y: s.height / 24)
            for x in [5.5, 13.5] {
                let r = Path(roundedRect: CGRect(x: x, y: 4, width: 5, height: 16), cornerRadius: 2)
                ctx.fill(r, with: .color(fill))
                ctx.stroke(r, with: .color(.cute.ink), lineWidth: 1.6)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 진행 바: 바탕 sidebar, ink 테두리, 채움 tomato + 오른쪽 끝 ink 선
struct CuteProgressBar: View {
    let fraction: Double
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * max(0, min(1, fraction))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(Color.cute.sidebar)
                if w > 0 {
                    Rectangle().fill(Color.cute.tomato).frame(width: w)
                        .overlay(alignment: .trailing) { Rectangle().fill(Color.cute.ink).frame(width: 2) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.cute.ink, lineWidth: 2))
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// 프로젝트 칩: 파스텔 배경 + ink 글자
struct ProjectChip: View {
    let project: Project
    var fontSize: CGFloat = 12

    var body: some View {
        Text(project.rawValue)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(Color.cute.ink)
            .padding(.vertical, 2)
            .padding(.horizontal, fontSize < 12 ? 8 : 10)
            .background(project.cuteChip, in: RoundedRectangle(cornerRadius: 10))
    }
}
