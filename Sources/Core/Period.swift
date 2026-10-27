import Foundation

/// 할 일의 기간 (시작일은 선택, 마감일은 필수). 날짜는 하루 단위(startOfDay)로 다룸
enum Period {
    private static var calendar: Calendar { .current }

    /// `11/3`, `~11/3`, `10/27~10/31`, `오늘~내일` 형식을 해석.
    /// 연도가 없으므로 마감일이 오늘 이전이면 내년으로, 시작일이 마감일보다 뒤면 작년으로 추정
    static func parse(_ text: String, now: Date = Date()) -> (start: Date?, due: Date)? {
        let today = calendar.startOfDay(for: now)
        let parts = text.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
        guard (1...2).contains(parts.count), let dueToken = parts.last,
              let due = day(dueToken, today: today) else { return nil }
        guard parts.count == 2, !parts[0].isEmpty else { return (nil, due) }
        guard let start = day(parts[0], today: today, notAfter: due) else { return nil }
        return (start, due)
    }

    /// `10/27~10/31` 또는 `~11/3`
    static func text(start: Date?, due: Date) -> String {
        (start.map(md) ?? "") + "~" + md(due)
    }

    /// 마감까지 남은 날 수 (오늘 마감이면 0, 지났으면 음수)
    static func daysLeft(until due: Date, now: Date = Date()) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
    }

    static func ddayText(until due: Date, now: Date = Date()) -> String {
        let n = daysLeft(until: due, now: now)
        return n == 0 ? "D-day" : n > 0 ? "D-\(n)" : "D+\(-n)"
    }

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    // MARK: - Private

    private static func md(_ date: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)/\(c.day ?? 0)"
    }

    private static func day(_ token: String, today: Date, notAfter limit: Date? = nil) -> Date? {
        switch token.lowercased() {
        case "오늘", "today": return today
        case "내일", "tomorrow": return calendar.date(byAdding: .day, value: 1, to: today)
        default: break
        }
        let nums = token.split(separator: "/").compactMap { Int($0) }
        guard nums.count == 2, token.split(separator: "/").count == 2 else { return nil }
        let (month, dayOfMonth) = (nums[0], nums[1])

        let baseYear = calendar.component(.year, from: limit ?? today)
        guard var date = make(year: baseYear, month: month, day: dayOfMonth) else { return nil }
        if let limit {
            if date > limit, let earlier = make(year: baseYear - 1, month: month, day: dayOfMonth) { date = earlier }
        } else if date < today, let later = make(year: baseYear + 1, month: month, day: dayOfMonth) {
            date = later
        }
        return date
    }

    /// 2/30처럼 없는 날짜는 nil (Calendar가 3/2로 넘기는 것을 막음)
    private static func make(year: Int, month: Int, day: Int) -> Date? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let c = calendar.dateComponents([.month, .day], from: date)
        return c.month == month && c.day == day ? date : nil
    }
}
