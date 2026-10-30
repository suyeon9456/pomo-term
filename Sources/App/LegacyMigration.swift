import Foundation

/// 1.0 출시 전에는 번들 ID가 com.local.pomodorotodo였음.
/// 테마·미니 타이머 위치 같은 앱 설정(UserDefaults)은 번들 ID별로 따로 저장되므로 처음 한 번 옮겨 옴.
/// 할 일 데이터(~/Library/Application Support/PomodoroTodo/data.json)는 경로가 같아서 그대로 이어짐
enum LegacyMigration {
    private static let oldDomain = "com.local.pomodorotodo"
    private static let doneKey = "migratedFromLegacyBundleID"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        if let old = defaults.persistentDomain(forName: oldDomain) {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: doneKey)
    }
}
