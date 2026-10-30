import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage(ThemeID.storageKey) private var themeID: ThemeID = .terminal

    private var light: LightPalette? { themeID.light }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("테마").font(.headline)
                LazyVGrid(columns: [GridItem(.fixed(196)), GridItem(.fixed(196))], alignment: .leading, spacing: 12) {
                    ForEach(ThemeID.allCases) { ThemeCard(theme: $0, selected: $0 == themeID) { themeID = $0 } }
                }
            }

            Form {
                Stepper("집중: \(store.settings.focusMinutes)분", value: $store.settings.focusMinutes, in: 1...120)
                Stepper("짧은 휴식: \(store.settings.shortBreakMinutes)분", value: $store.settings.shortBreakMinutes, in: 1...60)
                Stepper("긴 휴식: \(store.settings.longBreakMinutes)분", value: $store.settings.longBreakMinutes, in: 1...90)
                Stepper("긴 휴식 간격: 뽀모도로 \(store.settings.longBreakInterval)회마다",
                        value: $store.settings.longBreakInterval, in: 2...10)
                Toggle("집중이 끝나면 휴식 자동 시작", isOn: $store.settings.autoStartBreak)
                Toggle("휴식이 끝나면 집중 자동 시작", isOn: $store.settings.autoStartFocus)
                Toggle("완료 시 소리 재생", isOn: $store.settings.playSound)
                Toggle("\(GlobalHotKey.displayName)로 어디서든 시작/일시정지", isOn: $store.settings.globalHotKey)
                Text("VS Code 등 \(GlobalHotKey.displayName)를 쓰는 앱과 겹치면 꺼 주세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(light.map { .system(size: 13, design: $0.design) } ?? .term(13))
        }
        .tint(light?.accent ?? Color.term.accentFocus)
        .padding(20)
        .frame(width: 480)
        .background(light?.window ?? Color.term.window)
        .preferredColorScheme(light != nil ? .light : .dark)
        .animation(.easeInOut(duration: 0.25), value: themeID)
    }
}

/// 테마 선택 카드: 작은 미리보기 + 이름
private struct ThemeCard: View {
    let theme: ThemeID
    let selected: Bool
    let onSelect: (ThemeID) -> Void

    var body: some View {
        Button { onSelect(theme) } label: {
            VStack(spacing: 8) {
                preview
                    .frame(width: 180, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .circular))
                Text(theme.displayName).font(.system(size: 13, weight: .semibold))
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .circular)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) 테마")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var preview: some View {
        switch theme {
        case .terminal:
            VStack(alignment: .leading, spacing: 2) {
                Text("$ pomo focus").font(.term(9)).foregroundStyle(Color.term.accentFocus)
                Text("18:42").font(.term(34, .extraBold)).foregroundStyle(Color.term.accentFocus)
                Text("[██████░░░░░░] 25%").font(.term(9)).foregroundStyle(Color.term.accentFocus)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.term.window)
        case .cute:
            HStack(spacing: 10) {
                ZStack {
                    CuteRing(progress: 0.25, mode: .focus, diameter: 56, lineWidth: 7)
                    TomatoMascot(mood: .idle, size: 40, lineScale: 2, simple: true)
                }
                Text("18:42").font(.system(size: 28, weight: .light)).monospacedDigit().foregroundStyle(Color.cute.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: 0xFFF6EF))
        case .pom:
            dogPreview(.seol)
        }
    }

    private func dogPreview(_ dog: DogStyle) -> some View {
        HStack(spacing: 12) {
            DogAvatar(file: dog.avatarHappy, size: 54, background: dog.sidebar)
            Text("18:42").font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(dog.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dog.focusPanel)
    }
}
