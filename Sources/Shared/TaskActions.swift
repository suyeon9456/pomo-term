import SwiftUI

/// 할 일 우클릭 메뉴와 [⋯] 메뉴에 공통으로 들어가는 항목 (모든 테마)
struct TaskMenuItems: View {
    @EnvironmentObject var store: AppStore
    let item: TodoItem
    let depth: Int
    let onToggleDone: () -> Void
    let onEditPeriod: () -> Void

    private var isStory: Bool { depth == 0 && store.hasChildren(item) }

    var body: some View {
        if !item.isDone { Button("집중하기") { store.select(item) } }
        Button(item.isDone ? "미완료로 되돌리기" : "완료", action: onToggleDone)
        Button("제목 수정") { store.beginRename(item) }
        Divider()
        if depth == 0 && !item.isDone {
            Button("하위 태스크 추가…") { store.beginAdd(.sub(item.id)) }
        }
        if isStory {
            Button(item.isCollapsed ? "펼치기" : "접기") { store.setCollapsed(item, !item.isCollapsed) }
        }
        Divider()
        Button(item.isScheduled ? "기간 변경…" : "기간 설정…", action: onEditPeriod)
        if item.isScheduled { Button("기간 해제 (오늘 할 일로)") { store.setPeriod(item, start: nil, due: nil) } }
        Picker("태그", selection: Binding(get: { item.project },
                                         set: { p in store.setProject(item, p) })) {
            ForEach(Project.allCases, id: \.self) { Text("#\($0.rawValue)").tag($0) }
        }
        Picker("집중 시간", selection: Binding(get: { item.focusMinutes },
                                           set: { m in store.setFocusMinutes(item, m) })) {
            Text("기본 (\(store.settings.focusMinutes)분)").tag(Int?.none)
            Divider()
            ForEach(Self.focusPresets, id: \.self) { Text("\($0)분").tag(Int?.some($0)) }
            if let m = item.focusMinutes, !Self.focusPresets.contains(m) {
                Text("\(m)분").tag(Int?.some(m))
            }
        }
        Picker("예상 뽀모도로", selection: Binding(get: { item.estimatedPomodoros },
                                             set: { n in store.update(item) { $0.estimatedPomodoros = n } })) {
            ForEach(1...8, id: \.self) { Text("\($0)").tag($0) }
        }
        Divider()
        let kids = store.children(of: item).count
        Button(kids > 0 ? "삭제 (태스크 \(kids)개 포함)" : "삭제", role: .destructive) { store.delete(item) }
    }

    static let focusPresets = [15, 25, 30, 45, 50, 60, 90]
}

extension View {
    /// 열린 태스크가 있는 스토리를 완료할 때 태스크도 함께 완료할지 묻는 확인 창
    func storyCompletionDialog(_ item: TodoItem, isPresented: Binding<Bool>, store: AppStore) -> some View {
        confirmationDialog("열린 태스크 \(store.openChildrenCount(item))개가 있어요", isPresented: isPresented) {
            Button("태스크까지 모두 완료") { store.toggleDone(item, includeTasks: true) }
            Button("스토리만 완료") { store.toggleDone(item) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(item.title)을(를) 완료로 표시할까요?")
        }
    }
}

extension AppStore {
    /// 체크 버튼: 열린 태스크가 있는 스토리면 확인 창을 띄우고, 아니면 바로 토글
    func requestToggleDone(_ item: TodoItem, confirm: Binding<Bool>) {
        if !item.isDone && openChildrenCount(item) > 0 {
            confirm.wrappedValue = true
        } else {
            toggleDone(item)
        }
    }
}

/// 제목을 그 자리에서 고치는 입력칸. Enter나 다른 곳을 누르면 저장, Esc는 취소.
/// 모양은 테마가 감싸서 꾸밈
struct RenameField: View {
    @EnvironmentObject var store: AppStore
    let item: TodoItem
    @State private var text: String
    @FocusState private var focused: Bool

    init(item: TodoItem) {
        self.item = item
        _text = State(initialValue: item.title)
    }

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .onSubmit(save)
            .onExitCommand { store.renamingID = nil }
            .onAppear { DispatchQueue.main.async { focused = true } }
            .onChange(of: focused) { isFocused in
                if !isFocused && store.renamingID == item.id { save() }
            }
            .accessibilityLabel("\(item.title) 제목 수정")
    }

    private func save() {
        store.rename(item, text)
        store.renamingID = nil
    }
}

/// 스냅샷에서 마우스 오버 버튼을 확인하기 위한 스위치
enum TaskRowDebug {
    static var alwaysShowActions = false
}
