import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
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
        .font(.term(13))
        .tint(Color.term.accentFocus)
        .padding(20)
        .frame(width: 400)
        .background(Color.term.window)
        .preferredColorScheme(.dark)
    }
}
