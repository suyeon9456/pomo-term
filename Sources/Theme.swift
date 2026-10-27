import AppKit
import SwiftUI

// MARK: - Colors

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// 터미널 테마 디자인 토큰 (terminal-design-handoff.md 1장)
    enum term {
        static let window = Color(hex: 0x0E1111)
        static let titlebar = Color(hex: 0x171B1B)
        static let cmdline = Color(hex: 0x0B0E0E)
        static let activeRow = Color(hex: 0x152019)
        static let tabActive = Color(hex: 0x1A2420)

        static let border = Color(hex: 0x2A302F)
        static let borderStrong = Color(hex: 0x39403F)
        static let borderDashed = Color(hex: 0x1F2524)

        static let text = Color(hex: 0xC9D1C8)
        static let bright = Color(hex: 0xE8EDE7)
        static let dim = Color(hex: 0x8C9893)
        static let muted = Color(hex: 0x6F7C77)

        static let accentFocus = Color(hex: 0x7FD962)
        static let accentBreak = Color(hex: 0xE6B450)
        static let error = Color(hex: 0xF2786A)

        static let tagWork = Color(hex: 0x7AB8FF)
        static let tagPersonal = Color(hex: 0xC79BFF)
        static let tagStudy = Color(hex: 0x7FD962)
    }
}

extension TimerMode {
    var accent: Color { self == .focus ? .term.accentFocus : .term.accentBreak }

    /// 명령어·로그에 쓰는 이름 (focus / short / long)
    var key: String {
        switch self {
        case .focus: return "focus"
        case .shortBreak: return "short"
        case .longBreak: return "long"
        }
    }

    var upper: String {
        switch self {
        case .focus: return "FOCUS"
        case .shortBreak: return "SHORT BREAK"
        case .longBreak: return "LONG BREAK"
        }
    }
}

extension Project {
    var color: Color {
        switch self {
        case .work: return .term.tagWork
        case .personal: return .term.tagPersonal
        case .study: return .term.tagStudy
        }
    }
}

extension LogEntry.Kind {
    var color: Color {
        switch self {
        case .plain: return .term.text
        case .info, .echo: return .term.dim
        case .success: return .term.accentFocus
        case .warn: return .term.accentBreak
        case .error: return .term.error
        case .add: return .term.tagWork
        }
    }
}

// MARK: - Fonts

enum TermWeight {
    case regular, medium, bold, extraBold

    fileprivate var latinName: String {
        switch self {
        case .regular: return "JetBrainsMono-Regular"
        case .medium: return "JetBrainsMono-Medium"
        case .bold: return "JetBrainsMono-Bold"
        case .extraBold: return "JetBrainsMono-ExtraBold"
        }
    }

    // Nanum Gothic Coding은 400/700 두 굵기뿐
    fileprivate var hangulName: String {
        switch self {
        case .regular, .medium: return "NanumGothicCoding"
        case .bold, .extraBold: return "NanumGothicCoding-Bold"
        }
    }

    fileprivate var systemWeight: NSFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
}

extension Font {
    /// JetBrains Mono + 한글은 Nanum Gothic Coding으로 폴백하는 터미널 폰트
    static func term(_ size: CGFloat, _ weight: TermWeight = .regular) -> Font {
        Font(NSFont.term(size, weight) as CTFont)
    }
}

extension NSFont {
    private static var cache: [String: NSFont] = [:]

    static func term(_ size: CGFloat, _ weight: TermWeight = .regular) -> NSFont {
        let key = "\(weight.latinName)-\(size)"
        if let cached = cache[key] { return cached }

        let font: NSFont
        if let base = NSFont(name: weight.latinName, size: size) {
            let hangul = NSFontDescriptor(name: weight.hangulName, size: size)
            let descriptor = base.fontDescriptor.addingAttributes([.cascadeList: [hangul]])
            font = NSFont(descriptor: descriptor, size: size) ?? base
        } else {
            font = .monospacedSystemFont(ofSize: size, weight: weight.systemWeight)
        }
        cache[key] = font
        return font
    }
}
