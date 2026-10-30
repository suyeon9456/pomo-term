import SwiftUI

/// 강아지 테마(설이 · 골든 타임) 공통. 레이아웃은 하나이고 색 · 문구 · 이미지 · 장식만 테마마다 다름
/// (dog-themes/theme-architecture.md, pom-theme-handoff.md, golden-theme-handoff.md)
struct DogStyle {
    /// 타이머 패널 가운데 강아지를 보여주는 방식
    enum Scene {
        /// 골든: 배경 있는 장면 카드 + 상태 라벨 + 말풍선 (+ 움직임)
        case card
        /// 설이: 투명 PNG를 패널 위에 바로 + 발밑 그림자
        case cutout
    }

    /// 진행 표시
    enum Trail {
        /// 골든: 발자국 12개 지그재그
        case paws
        /// 설이: 털뭉치 24개 한 줄
        case puffs
    }

    /// 뽀모도로 개수 아이콘
    enum Treat {
        case tennisBall, bone
    }

    let appName: String
    let scene: Scene
    let trail: Trail
    let treat: Treat
    let todayIcon: DogNavIcon.Kind
    let doneIcon: DogNavIcon.Kind

    // MARK: 색
    let text: Color
    let textSecondary: Color
    /// 강조 배경(accent) 위 글자·아이콘
    let textOnAccent: Color
    /// 개수 배지, 칩 글자, 메뉴 막대 아이콘
    let strong: Color
    let window: Color
    let sidebar: Color
    let inputBorder: Color
    let track: Color
    let focusAccent: Color
    let breakAccent: Color
    let focusPanel: Color
    let breakPanel: Color
    /// 아직 안 채운 발자국·털뭉치
    let trailEmpty: Color
    /// 집중 중인 할 일 카드 배경
    let activeRowBg: Color
    let checkboxBorder: Color
    /// "같이 하기 / 함께하기" 버튼 배경
    let softButton: Color
    /// 그림자 색 (rgba(120,80,30) / rgba(140,100,80))
    let shadow: Color
    let placeholder: Color
    /// 세션 발바닥: 끝남 / 진행 중 / 남음 (골든은 채움 색만, 설이는 채움 + 테두리)
    let sessionDone: (fill: Color, stroke: Color?)
    let sessionCurrent: (fill: Color, stroke: Color?)
    let sessionUpcoming: (fill: Color, stroke: Color?)
    private let chips: [Project: Color]
    private let dots: [Project: Color]

    // MARK: 크기
    let cardRadius: CGFloat
    let panelRadius: CGFloat
    let timerSize: CGFloat
    let panelWidth: CGFloat

    // MARK: 문구
    let subtitle: String
    let shortBreakName: String
    let longBreakName: String
    let doneTitle: String
    let doneVerb: String
    let treatNoun: String
    let todayCardTitle: String
    let todayCardSuffix: String
    let inputPlaceholder: String
    let addButton: String
    let focusButton: String
    let focusButtonActive: String
    let currentTaskTitle: String
    let noTaskText: String
    let nextListTitle: String
    let popoverCaption: String

    /// 장면 카드 위 말풍선 (골든만). 설이는 시안대로 말풍선 없음
    let speech: DogSpeech?

    // MARK: 이미지
    let mascotImages: [MascotState: String]
    let mascotLabels: [MascotState: String]
    let avatarHappy: String
    let avatarSleep: String
    let menuBarImage: String
    let menuBarImageLabel: String

    func chip(_ project: Project) -> Color { chips[project] ?? sidebar }
    func dot(_ project: Project) -> Color { dots[project] ?? textSecondary }
    func accent(_ mode: TimerMode) -> Color { mode == .focus ? focusAccent : breakAccent }
    func panel(_ mode: TimerMode) -> Color { mode == .focus ? focusPanel : breakPanel }

    static func of(_ theme: ThemeID) -> DogStyle? {
        switch theme {
        case .pom: return .seol
        case .golden: return .golden
        default: return nil
        }
    }

    func modeName(_ mode: TimerMode) -> String {
        switch mode {
        case .focus: return "집중"
        case .shortBreak: return shortBreakName
        case .longBreak: return longBreakName
        }
    }
}

struct DogSpeech {
    let idle: String
    /// 남은 분을 받아서 문구를 만듦
    let focusing: (Int) -> String
    let breakIdle: String
    let breakRunning: String

    func text(state: MascotState, running: Bool, leftMinutes: Int) -> String {
        switch state {
        case .idle: return idle
        case .focusing: return focusing(leftMinutes)
        case .shortBreak, .longBreak: return running ? breakRunning : breakIdle
        }
    }
}

/// 마스코트 상태 (강아지 테마 공통)
enum MascotState: Hashable {
    case idle, focusing, shortBreak, longBreak

    init(mode: TimerMode, isRunning: Bool) {
        switch mode {
        case .focus: self = isRunning ? .focusing : .idle
        case .shortBreak: self = .shortBreak
        case .longBreak: self = .longBreak
        }
    }
}

// MARK: - 설이 (하얀 포메라니안)

extension DogStyle {
    static let seol = DogStyle(
        appName: "설이",
        scene: .cutout, trail: .puffs, treat: .bone, todayIcon: .paw, doneIcon: .check,
        text: Color(hex: 0x4B3A35), textSecondary: Color(hex: 0x7D6760), textOnAccent: Color(hex: 0x4B2630),
        strong: Color(hex: 0xB4506A), window: Color(hex: 0xFFFDFB), sidebar: Color(hex: 0xFBF5F1),
        inputBorder: Color(hex: 0xF0E3DB), track: Color(hex: 0xF3E7E1),
        focusAccent: Color(hex: 0xF4A9B8), breakAccent: Color(hex: 0x9CC6EA),
        focusPanel: Color(hex: 0xFDF2F4), breakPanel: Color(hex: 0xEEF5FB),
        trailEmpty: Color(hex: 0xEFE3DC), activeRowBg: Color(hex: 0xFFF5F7), checkboxBorder: Color(hex: 0xCDB6AB),
        softButton: Color(hex: 0xFBF0EC), shadow: Color(red: 140 / 255, green: 100 / 255, blue: 80 / 255),
        placeholder: Color(hex: 0x8E7A73),
        sessionDone: (Color(hex: 0xF4A9B8), Color(hex: 0xF4A9B8)),
        sessionCurrent: (.white, Color(hex: 0xF4A9B8)),
        sessionUpcoming: (.white, Color(hex: 0xE2D3C6)),
        chips: [.work: Color(hex: 0xE3EEF8), .personal: Color(hex: 0xFBE6EA), .study: Color(hex: 0xEAF3E3)],
        dots: [.work: Color(hex: 0x7FA9D6), .personal: Color(hex: 0xE894A6), .study: Color(hex: 0x97C08A)],
        cardRadius: 20, panelRadius: 30, timerSize: 62, panelWidth: 380,
        subtitle: "몽글몽글하게 해봐요",
        shortBreakName: "간식 타임", longBreakName: "긴 놀이",
        doneTitle: "쓰담받은 일", doneVerb: "쓰담받음", treatNoun: "간식",
        todayCardTitle: "오늘 받은 간식", todayCardSuffix: "함께했어요",
        inputPlaceholder: "할 일을 알려주세요 (Enter)", addButton: "추가",
        focusButton: "함께하기", focusButtonActive: "함께하는 중",
        currentTaskTitle: "함께하는 일", noTaskText: "목록에서 함께할 일을 골라주세요",
        nextListTitle: "다음에 함께할 일", popoverCaption: "엎드려서 기다리는 중…",
        speech: nil,
        mascotImages: [.idle: "pom-idle.png", .focusing: "pom-focus.png",
                       .shortBreak: "pom-short-break.png", .longBreak: "pom-long-break.png"],
        mascotLabels: [.idle: "앉아서 웃고 있는 하얀 포메라니안",
                       .focusing: "방석 위에서 동그랗게 잠든 하얀 포메라니안",
                       .shortBreak: "테니스공을 물고 뛰어오는 하얀 포메라니안",
                       .longBreak: "테니스공을 물고 신나게 달리는 하얀 포메라니안"],
        avatarHappy: "pom-avatar-happy.jpg", avatarSleep: "pom-avatar-sleep.jpg",
        menuBarImage: "pom-menubar.png", menuBarImageLabel: "엎드려서 기다리는 하얀 포메라니안"
    )
}

// MARK: - 골든 타임 (골든 리트리버)

extension DogStyle {
    static let golden = DogStyle(
        appName: "골든 타임",
        scene: .card, trail: .paws, treat: .tennisBall, todayIcon: .sun, doneIcon: .paw,
        text: Color(hex: 0x4A3320), textSecondary: Color(hex: 0x7A5E45), textOnAccent: Color(hex: 0x3A2617),
        strong: Color(hex: 0xA8641A), window: Color(hex: 0xFFFBF4), sidebar: Color(hex: 0xFBF1E0),
        inputBorder: Color(hex: 0xEFE0C6), track: Color(hex: 0xF3E6CF),
        focusAccent: Color(hex: 0xE8A945), breakAccent: Color(hex: 0x8CC084),
        focusPanel: Color(hex: 0xFBF1E0), breakPanel: Color(hex: 0xEAF4E2),
        trailEmpty: Color(hex: 0xE3D3B8), activeRowBg: Color(hex: 0xFFF3DD), checkboxBorder: Color(hex: 0xC9A67A),
        softButton: Color(hex: 0xFBF1E0), shadow: Color(red: 120 / 255, green: 80 / 255, blue: 30 / 255),
        placeholder: Color(hex: 0x8C7258),
        sessionDone: (Color(hex: 0xE8A945), nil),
        sessionCurrent: (Color(hex: 0xC9A67A), nil),
        sessionUpcoming: (Color(hex: 0xE9DCC6), nil),
        chips: [.work: Color(hex: 0xDDEBF7), .personal: Color(hex: 0xF7E1E1), .study: Color(hex: 0xE3F0D8)],
        dots: [.work: Color(hex: 0x4C8DCB), .personal: Color(hex: 0xE08A8A), .study: Color(hex: 0x7DAF6E)],
        cardRadius: 18, panelRadius: 28, timerSize: 64, panelWidth: 370,
        subtitle: "오늘도 잘 해낼 거예요",
        shortBreakName: "짧은 산책", longBreakName: "긴 산책",
        doneTitle: "칭찬받은 일", doneVerb: "칭찬받음", treatNoun: "공",
        todayCardTitle: "오늘 물어온 공", todayCardSuffix: "함께 집중했어요",
        inputPlaceholder: "할 일을 던져주면 물어올게요! (Enter)", addButton: "던지기",
        focusButton: "같이 하기", focusButtonActive: "함께 집중 중",
        currentTaskTitle: "함께 집중하는 일", noTaskText: "목록에서 같이 할 일을 골라주세요",
        nextListTitle: "다음에 같이 할 일", popoverCaption: "조용히 기다리는 중…",
        speech: DogSpeech(idle: "같이 시작할까요? 꼬리 흔드는 중!",
                          focusing: { "옆에서 조용히 기다릴게요… \($0)분" },
                          breakIdle: "잘했어요! 산책 갈까요?",
                          breakRunning: "공 던져주세요! 신나요~"),
        mascotImages: [.idle: "golden-idle.jpg", .focusing: "golden-focus.jpg",
                       .shortBreak: "golden-break.jpg", .longBreak: "golden-break.jpg"],
        mascotLabels: [.idle: "책상 옆에 앉아 꼬리 흔드는 리트리버 강아지",
                       .focusing: "방석 위에서 잠든 리트리버 강아지",
                       .shortBreak: "공원에서 테니스공을 물고 걸어오는 리트리버 강아지",
                       .longBreak: "공원에서 테니스공을 물고 걸어오는 리트리버 강아지"],
        avatarHappy: "golden-avatar-happy.jpg", avatarSleep: "golden-avatar-sleep.jpg",
        menuBarImage: "golden-menubar.jpg", menuBarImageLabel: "방석 위에서 잠든 리트리버 강아지"
    )
}
