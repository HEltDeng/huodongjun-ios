import Foundation

enum DraftField: String, CaseIterable { case title, location, start, end, deadline, audience, capacity, groupLink }
enum FormValidation {
    static func event(_ event: CampusEvent, needsAudience: Bool = false, allowPastStart: Bool = false, now: Date = Date()) -> [DraftField: String] {
        var errors = [DraftField: String]()
        if event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors[.title] = "请填写活动名称" }
        if event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors[.location] = "请填写具体地点或集合位置" }
        if !allowPastStart && event.start <= now { errors[.start] = "开始时间应晚于现在" }
        if event.end <= event.start { errors[.end] = "结束时间应晚于开始时间" }
        if event.deadline > event.start { errors[.deadline] = "报名截止时间不能晚于活动开始时间" }
        if !allowPastStart && event.deadline <= now { errors[.deadline] = "报名截止时间应晚于现在" }
        if needsAudience && event.audienceSchoolIDs.isEmpty { errors[.audience] = "请至少选择一所可以报名的学校" }
        if !(1...10000).contains(event.capacity) || event.capacity < event.baseAttendees { errors[.capacity] = "人数上限应为 1～10000 人，且不少于已报名人数" }
        if !event.group.link.isEmpty && EventRules.safeGroupURL(event.group.link) == nil { errors[.groupLink] = "请使用完整的 HTTPS 群链接" }
        return errors
    }
    static func required(_ value: String, title: String) -> String? { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请填写\(title)" : nil }
    static func points(_ value: String) -> Int? {
        guard value.range(of: #"^\d{1,3}(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")), decimal >= 0, decimal <= 100 else { return nil }
        return NSDecimalNumber(decimal: decimal * 100).intValue
    }
}
