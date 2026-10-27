import SwiftUI

/// 우클릭 → 기간 설정… 에서 여는 시트
struct PeriodEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("── period ───────").font(.term(13, .bold)).foregroundStyle(Color.term.accentFocus)
            Text(item.title).foregroundStyle(Color.term.bright).lineLimit(2)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Toggle("start", isOn: $hasStart).toggleStyle(.checkbox)
                    DatePicker("", selection: $start, displayedComponents: .date).labelsHidden().disabled(!hasStart)
                }
                GridRow {
                    Text("due").foregroundStyle(Color.term.dim)
                    DatePicker("", selection: $due, displayedComponents: .date).labelsHidden()
                }
            }

            Text(isValid ? "\(Period.text(start: hasStart ? start : nil, due: due))  \(Period.ddayText(until: due))"
                         : "✗ 시작일이 마감일보다 늦어요")
                .font(.term(12))
                .foregroundStyle(isValid ? Color.term.dim : Color.term.error)

            HStack(spacing: 8) {
                if item.isScheduled {
                    OutlineButton(title: "기간 해제", label: "기간 해제", height: 36, fontSize: 13) {
                        store.setPeriod(item, start: nil, due: nil)
                        dismiss()
                    }
                }
                Spacer()
                OutlineButton(title: "취소", label: "취소", height: 36, fontSize: 13) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    store.setPeriod(item, start: hasStart ? start : nil, due: due)
                    dismiss()
                } label: {
                    Text("저장")
                        .font(.term(13, .extraBold))
                        .foregroundStyle(Color.term.window)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(isValid ? Color.term.accentFocus : Color.term.muted, in: RoundedRectangle(cornerRadius: 4))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .font(.term(13))
        .foregroundStyle(Color.term.text)
        .padding(22)
        .frame(width: 400)
        .background(Color.term.window)
        .preferredColorScheme(.dark)
    }
}
