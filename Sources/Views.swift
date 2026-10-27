import SwiftUI

extension TimerMode {
    var color: Color {
        switch self {
        case .focus: return Color(red: 0.91, green: 0.33, blue: 0.29)
        case .shortBreak: return Color(red: 0.22, green: 0.62, blue: 0.56)
        case .longBreak: return Color(red: 0.30, green: 0.48, blue: 0.80)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HSplitView {
            TimerPanel()
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
            TodoPanel()
                .frame(minWidth: 320)
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}

// MARK: - Timer

struct TimerPanel: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 20) {
            Picker("", selection: Binding(get: { store.mode }, set: { store.switchMode($0) })) {
                ForEach(TimerMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ZStack {
                Circle().stroke(store.mode.color.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: store.progress)
                    .stroke(store.mode.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: store.progress)
                VStack(spacing: 6) {
                    Text(store.timeString)
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("\(store.mode.emoji) \(store.mode.label)")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 12) {
                Button(action: store.reset) { Image(systemName: "arrow.counterclockwise") }
                    .help("초기화")
                Button(action: store.toggle) {
                    Label(store.isRunning ? "일시정지" : "시작",
                          systemImage: store.isRunning ? "pause.fill" : "play.fill")
                        .frame(width: 100)
                }
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.borderedProminent)
                .tint(store.mode.color)
                .controlSize(.large)
                Button(action: store.skip) { Image(systemName: "forward.end.fill") }
                    .help("건너뛰기")
            }

            VStack(spacing: 4) {
                Text("현재 작업").font(.caption).foregroundStyle(.secondary)
                Text(store.selectedTodo?.title ?? "할 일을 선택하세요")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Text("오늘 완료한 뽀모도로: \(store.todayCount)개")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

// MARK: - Todos

struct TodoPanel: View {
    @EnvironmentObject var store: AppStore
    @State private var newTitle = ""
    @State private var newEstimate = 1
    @FocusState private var fieldFocused: Bool

    private var active: [TodoItem] { store.todos.filter { !$0.isDone } }
    private var done: [TodoItem] { store.todos.filter { $0.isDone } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("새 할 일 추가…", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit(add)
                Stepper("🍅 \(newEstimate)", value: $newEstimate, in: 1...12)
                    .fixedSize()
                Button("추가", action: add)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)

            Divider()

            if store.todos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist").font(.largeTitle).foregroundStyle(.tertiary)
                    Text("할 일을 추가해 보세요").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("진행 중 (\(active.count))") {
                        ForEach(active) { TodoRow(item: $0) }
                    }
                    if !done.isEmpty {
                        Section {
                            ForEach(done) { TodoRow(item: $0) }
                        } header: {
                            HStack {
                                Text("완료 (\(done.count))")
                                Spacer()
                                Button("완료 항목 지우기", action: store.clearDone)
                                    .buttonStyle(.link)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func add() {
        store.addTodo(newTitle, estimate: newEstimate)
        newTitle = ""
        newEstimate = 1
        fieldFocused = true
    }
}

struct TodoRow: View {
    @EnvironmentObject var store: AppStore
    let item: TodoItem

    private var isSelected: Bool { store.selectedTodoID == item.id }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggleDone(item) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                Text(pomodoroText)
                    .font(.caption)
                    .foregroundStyle(item.completedPomodoros > item.estimatedPomodoros ? .orange : .secondary)
            }

            Spacer()

            if isSelected && !item.isDone {
                Text("진행 중")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(TimerMode.focus.color.opacity(0.15), in: Capsule())
                    .foregroundStyle(TimerMode.focus.color)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { if !item.isDone { store.selectedTodoID = item.id } }
        .listRowBackground(isSelected && !item.isDone ? TimerMode.focus.color.opacity(0.08) : Color.clear)
        .contextMenu {
            if !item.isDone { Button("현재 작업으로 선택") { store.selectedTodoID = item.id } }
            Button(item.isDone ? "미완료로 되돌리기" : "완료") { store.toggleDone(item) }
            Divider()
            Button("삭제", role: .destructive) { store.delete(item) }
        }
    }

    private var pomodoroText: String {
        "🍅 \(item.completedPomodoros) / \(item.estimatedPomodoros)"
    }
}

// MARK: - Menu bar

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("\(store.mode.emoji) \(store.mode.label) · \(store.timeString)")
        if let todo = store.selectedTodo { Text("작업: \(todo.title)") }
        Divider()
        Button(store.isRunning ? "일시정지" : "시작", action: store.toggle)
        Button("건너뛰기", action: store.skip)
        Button("초기화", action: store.reset)
        Divider()
        Button("창 열기") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("종료") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Form {
            Stepper("집중: \(store.settings.focusMinutes)분", value: $store.settings.focusMinutes, in: 1...120)
            Stepper("짧은 휴식: \(store.settings.shortBreakMinutes)분", value: $store.settings.shortBreakMinutes, in: 1...60)
            Stepper("긴 휴식: \(store.settings.longBreakMinutes)분", value: $store.settings.longBreakMinutes, in: 1...90)
            Stepper("긴 휴식 간격: 뽀모도로 \(store.settings.longBreakInterval)회마다",
                    value: $store.settings.longBreakInterval, in: 2...10)
            Toggle("다음 타이머 자동 시작", isOn: $store.settings.autoStartNext)
            Toggle("완료 시 소리 재생", isOn: $store.settings.playSound)
        }
        .padding(20)
        .frame(width: 360)
    }
}
