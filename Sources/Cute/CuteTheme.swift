import SwiftUI

// MARK: - Colors (cute-design-handoff.md 2장)

extension Color {
    enum cute {
        static let ink = Color(hex: 0x3B2A24)
        static let inkSecondary = Color(hex: 0x7A5F55)
        static let placeholder = Color(hex: 0x8A6E63)
        static let window = Color(hex: 0xFFFDF9)
        static let sidebar = Color(hex: 0xFFF1E8)
        static let sidebarDivider = Color(hex: 0xF3DCCF)
        static let rowBorder = Color(hex: 0xF3E3D9)
        static let rowActiveBg = Color(hex: 0xFFF0E8)
        static let tomato = Color(hex: 0xF2674F)
        static let leaf = Color(hex: 0x6BBF7A)
        static let blush = Color(hex: 0xFF9AA2)
        static let butter = Color(hex: 0xFFC94D)
        static let emptyIcon = Color(hex: 0xC9B3A8)
        static let link = Color(hex: 0xC2412E)
        static let white = Color.white

        static let peach = Color(hex: 0xFFD3C4)   // 선택된 항목·집중 탭
        static let mint = Color(hex: 0xCDEFDF)    // 휴식 탭, 진행 중 세션 꼭지
        static let sky = Color(hex: 0xDCE8FF)
        static let lilac = Color(hex: 0xEDE2FF)
        static let sage = Color(hex: 0xD8F2E2)
    }
}

extension TimerMode {
    /// 링 진행, 재생 버튼
    var cuteAccent: Color { self == .focus ? Color(hex: 0xE8604C) : Color(hex: 0x3FA67E) }
    /// 링 바탕
    var cuteTrack: Color { self == .focus ? Color(hex: 0xFFE3D8) : Color(hex: 0xD8F2E2) }
    /// 선택된 모드 탭
    var cuteTab: Color { self == .focus ? Color.cute.peach : Color.cute.mint }
    /// 타이머 패널 배경
    var cutePanel: Color { self == .focus ? Color(hex: 0xFFF6EF) : Color(hex: 0xF1FAF5) }
}

extension Project {
    var cuteChip: Color {
        switch self {
        case .work: return .cute.sky
        case .personal: return .cute.lilac
        case .study: return .cute.sage
        }
    }
}

// MARK: - Surfaces (진한 외곽선 + 흐림 없는 그림자)

extension View {
    /// 채움 + ink 테두리 + 아래로 떨어지는 딱딱한 그림자
    func cuteSurface<S: InsettableShape>(_ shape: S, fill: Color, border: Color = .cute.ink,
                                         lineWidth: CGFloat = 2, shadow: CGFloat = 0) -> some View {
        background {
            ZStack {
                if shadow > 0 { shape.fill(Color.cute.ink).offset(y: shadow) }
                shape.fill(fill)
                shape.strokeBorder(border, lineWidth: lineWidth)
            }
        }
    }

    func cuteSurface(radius: CGFloat, fill: Color, border: Color = .cute.ink,
                     lineWidth: CGFloat = 2, shadow: CGFloat = 0) -> some View {
        cuteSurface(RoundedRectangle(cornerRadius: radius, style: .continuous),
                    fill: fill, border: border, lineWidth: lineWidth, shadow: shadow)
    }
}

/// 누르면 그림자만큼 내려가서 그림자가 사라지는 버튼
struct CuteButtonStyle: ButtonStyle {
    var fill: Color = .cute.white
    var radius: CGFloat = 14
    var shadow: CGFloat = 3
    var lineWidth: CGFloat = 2

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(Color.cute.ink)
            .background {
                ZStack {
                    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                    if shadow > 0 && !pressed { shape.fill(Color.cute.ink).offset(y: shadow) }
                    shape.fill(fill)
                    shape.strokeBorder(Color.cute.ink, lineWidth: lineWidth)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .offset(y: pressed ? shadow : 0)
    }
}

/// 원형 버튼 버전
struct CuteCircleButtonStyle: ButtonStyle {
    var fill: Color = .cute.white
    var size: CGFloat
    var shadow: CGFloat = 3
    var lineWidth: CGFloat = 2

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(Color.cute.ink)
            .frame(width: size, height: size)
            .background {
                ZStack {
                    if shadow > 0 && !pressed { Circle().fill(Color.cute.ink).offset(y: shadow) }
                    Circle().fill(fill)
                    Circle().strokeBorder(Color.cute.ink, lineWidth: lineWidth)
                }
            }
            .contentShape(Circle())
            .offset(y: pressed ? shadow : 0)
    }
}
