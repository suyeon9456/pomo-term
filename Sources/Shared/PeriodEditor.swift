import SwiftUI

/// 우클릭 → 기간 설정… 에서 여는 시트. 동작은 같고 모양만 테마를 따름
struct PeriodEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeID) private var themeID
    let item: TodoItem

    @State private var hasStart: Bool
    @State private var start: Date
    @State private var due: Date

    init(item: TodoItem) {
        self.item = item
        let today = Period.startOfDay(Date())
        _hasStart = State(initialValue: item.startDate != nil)
        _start = State(initialValue: item.startDate ?? today)
        _due = State(initialValue: item.dueDate ?? Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today)
    }

    private var isValid: Bool { !hasStart || Period.startOfDay(start) <= Period.startOfDay(due) }
    /// 터미널이 아니면 밝은 테마 색
    private var light: LightPalette? { themeID.light }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let light {
                Text("기간 정하기").font(.system(size: 18, weight: .bold, design: light.design)).foregroundStyle(light.text)
            } else {
                Text("── period ───────").font(.term(13, .bold)).foregroundStyle(Color.term.accentFocus)
            }
            Text(item.title).foregroundStyle(light?.text ?? Color.term.bright).lineLimit(2)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Toggle(light != nil ? "시작일" : "start", isOn: $hasStart).toggleStyle(.checkbox)
                    DatePicker("", selection: $start, displayedComponents: .date).labelsHidden().disabled(!hasStart)
                }
                GridRow {
                    Text(light != nil ? "마감일" : "due").foregroundStyle(light?.secondary ?? Color.term.dim)
                    DatePicker("", selection: $due, displayedComponents: .date).labelsHidden()
                }
            }

            Text(isValid ? "\(Period.text(start: hasStart ? start : nil, due: due))  \(Period.ddayText(until: due))"
                         : (light != nil ? "시작일이 마감일보다 늦어요" : "✗ 시작일이 마감일보다 늦어요"))
                .font(light.map { .system(size: 13, weight: .semibold, design: $0.design) } ?? .term(12))
                .foregroundStyle(isValid ? (light?.secondary ?? Color.term.dim) : (light?.error ?? Color.term.error))

            HStack(spacing: 8) {
                if item.isScheduled {
                    button("기간 해제", primary: false) {
                        store.setPeriod(item, start: nil, due: nil)
                        dismiss()
                    }
                }
                Spacer()
                button("취소", primary: false) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                button("저장", primary: true) {
                    store.setPeriod(item, start: hasStart ? start : nil, due: due)
                    dismiss()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .font(light.map { .system(size: 14, design: $0.design) } ?? .term(13))
        .foregroundStyle(light?.text ?? Color.term.text)
        .padding(22)
        .frame(width: 400)
        .background(light?.window ?? Color.term.window)
        .preferredColorScheme(light != nil ? .light : .dark)
    }

    @ViewBuilder
    private func button(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        if themeID == .cute {
            Button(action: action) {
                Text(title).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 16).frame(height: 36)
            }
            .buttonStyle(CuteButtonStyle(fill: primary ? (isValid ? .cute.butter : .cute.sidebar) : .white, radius: 12))
        } else if let dog = DogStyle.of(themeID) {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primary ? dog.textOnAccent : dog.text)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
            }
            .buttonStyle(DogButtonStyle(fill: primary ? (isValid ? dog.focusAccent : dog.track) : dog.softButton, radius: 14))
        } else if primary {
            Button(action: action) {
                Text(title)
                    .font(.term(13, .extraBold))
                    .foregroundStyle(Color.term.window)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(isValid ? Color.term.accentFocus : Color.term.muted, in: RoundedRectangle(cornerRadius: 4, style: .circular))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            OutlineButton(title: title, label: title, height: 36, fontSize: 13, action: action)
        }
    }
}
