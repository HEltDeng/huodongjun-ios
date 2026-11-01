import Foundation

enum CompetitionPhase: String, CaseIterable, Identifiable {
    case upcoming = "即将开始", ongoing = "进行中", ended = "已结束", unknown = "时间待公布"
    var id: String { rawValue }
}

enum CompetitionDates {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        value.firstWeekday = 2
        return value
    }
    static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false
        for format in ["yyyy年M月d日", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return ISO8601DateFormatter().date(from: text)
    }
    static func text(_ date: Date?, year: Bool = false) -> String {
        guard let date else { return "待公布" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = year ? "yyyy年M月d日" : "M月d日"
        return formatter.string(from: date)
    }
}

struct OfficialCompetition: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var category: String
    var platform: String
    var location: String
    var prize: String
    var participants: Int
    var tags: [String]
    var organizer: String?
    var start: Date?
    /// Source publishes a calendar date, inclusive in Asia/Shanghai. No invented exact deadline.
    var end: Date?
    var signupStatus: Int?
    var signupLink: String?
    var fetchedAt: Date?

    var sourceURL: URL { CompetitionSource.url(path: ["zh", "competitions", id]) }
    var signupURL: URL? { CompetitionSource.safeURL(signupLink) }
    var endExclusive: Date? { end.flatMap { CompetitionDates.calendar.date(byAdding: .day, value: 1, to: $0) } }
    var validInterval: Bool { guard let start, let end else { return false }; return end >= start }
    func phase(at now: Date = Date()) -> CompetitionPhase {
        guard validInterval, let start, let endExclusive else { return .unknown }
        if now < start { return .upcoming }
        return now >= endExclusive ? .ended : .ongoing
    }
    func elapsed(at now: Date = Date()) -> Double? {
        guard validInterval, let start, let endExclusive else { return nil }
        return min(1, max(0, now.timeIntervalSince(start) / endExclusive.timeIntervalSince(start)))
    }
    func timing(at now: Date = Date()) -> String {
        switch phase(at: now) {
        case .upcoming:
            let days = CompetitionDates.calendar.dateComponents([.day], from: CompetitionDates.calendar.startOfDay(for: now), to: start!).day ?? 0
            return days == 0 ? "今天开始" : "\(days) 天后开始"
        case .ongoing:
            let days = CompetitionDates.calendar.dateComponents([.day], from: CompetitionDates.calendar.startOfDay(for: now), to: end!).day ?? 0
            return days == 0 ? "今天结束" : "还剩 \(days) 天"
        case .ended: return "赛事已结束"
        case .unknown: return "时间待公布"
        }
    }
    func overlaps(month: Date) -> Bool {
        guard validInterval, let start, let endExclusive,
              let interval = CompetitionDates.calendar.dateInterval(of: .month, for: month) else { return false }
        return start < interval.end && endExclusive > interval.start
    }
    func milestone(on day: Date) -> String? {
        let calendar = CompetitionDates.calendar
        let begins = start.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let closes = end.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        if begins && closes { return "开始 · 结束" }
        if begins { return "开始" }
        if closes { return "结束" }
        return nil
    }
    var registrationText: String {
        if phase() == .ended { return "赛事已结束" }
        switch signupStatus {
        case 1, 2: return "报名开放"
        case 3: return "报名已截止"
        case 4: return "赛事已结束"
        default: return "报名状态待确认"
        }
    }
}

struct CompetitionCity: Identifiable, Codable, Equatable {
    var key: String
    var name: String
    var count: Int
    var id: String { key }
}
struct CompetitionRegion: Identifiable, Codable, Equatable {
    var key: String
    var name: String
    var cities: [CompetitionCity]
    var id: String { key }
}
struct CompetitionFeed: Codable {
    var items: [OfficialCompetition]
    var regions: [CompetitionRegion]
    var nextURL: URL?
    var fetchedAt: Date
}

enum CompetitionSource {
    static func url(path: [String]) -> URL {
        path.reduce(URL(string: "https://competehub.dev")!) { $0.appendingPathComponent($1) }
    }
    static func safeURL(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text), url.scheme == "https", let host = url.host,
              !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
    static func feedURL(city: String = "All") -> URL {
        url(path: ["zh", "regions", "China", city])
    }
    static func isChinaFeed(_ url: URL) -> Bool {
        let components = url.pathComponents
        return url.scheme == "https" && url.host == "competehub.dev" && url.user == nil && url.password == nil &&
            components.count == 5 && Array(components.prefix(4)) == ["/", "zh", "regions", "China"]
    }
}

/// Reads only the JSON data already delivered in public HTML. Never evaluates site JavaScript.
enum CompeteHubParser {
    static func objects(in html: String) throws -> [[String: Any]] {
        let regex = try NSRegularExpression(pattern: #"self\.__next_f\.push\((\[1,.*?\])\)</script>"#, options: [.dotMatchesLineSeparators])
        var flight = ""
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range(at: 1), in: html),
                  let data = String(html[range]).data(using: .utf8),
                  let values = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let part = values.last as? String else { continue }
            flight += part
        }
        var output = [[String: Any]]()
        func walk(_ value: Any) {
            if let dict = value as? [String: Any] { output.append(dict); dict.values.forEach(walk) }
            else if let list = value as? [Any] { list.forEach(walk) }
        }
        let bytes = Array(flight.utf8)
        var cursor = 0
        while cursor < bytes.count {
            if bytes[cursor] == 10 || bytes[cursor] == 13 { cursor += 1; continue }
            guard let colon = bytes[cursor...].firstIndex(of: 58),
                  colon == cursor || UInt(String(decoding: bytes[cursor..<colon], as: UTF8.self), radix: 16) != nil else {
                throw CompetitionLoadError.formatChanged
            }
            cursor = colon + 1
            // Long text frames are T<hex UTF-8 byte length>,<raw text>. The following
            // JSON frame may begin immediately, without a newline after that text.
            // Skip descriptions by their byte length; never interpret their text as records.
            if cursor < bytes.count, bytes[cursor] == 84 {
                guard let comma = bytes[cursor...].firstIndex(of: 44),
                      let length = Int(String(decoding: bytes[(cursor + 1)..<comma], as: UTF8.self), radix: 16),
                      length >= 0, length <= bytes.count - comma - 1 else { throw CompetitionLoadError.formatChanged }
                cursor = comma + 1 + length
            } else {
                let end = bytes[cursor...].firstIndex(of: 10) ?? bytes.count
                if let value = try? JSONSerialization.jsonObject(with: Data(bytes[cursor..<end])) { walk(value) }
                cursor = end < bytes.count ? end + 1 : end
            }
        }
        guard !output.isEmpty else { throw CompetitionLoadError.formatChanged }
        return output
    }
    static func feed(html: String, url: URL, now: Date = Date()) throws -> CompetitionFeed {
        guard CompetitionSource.isChinaFeed(url) else { throw CompetitionLoadError.unavailable }
        let objects = try objects(in: html)
        guard let region = objects.first(where: { $0["regionKey"] as? String == "China" && $0["currentCity"] as? String == url.lastPathComponent }) else {
            throw CompetitionLoadError.formatChanged
        }
        var seen = Set<String>()
        let items = objects.compactMap { $0["competition"] as? [String: Any] }.compactMap { dict -> OfficialCompetition? in
            guard let id = dict["id"] as? String, let title = dict["title"] as? String,
                  !title.isEmpty, seen.insert(id).inserted else { return nil }
            return OfficialCompetition(id: id, title: title, category: dict["displayCategory"] as? String ?? "AI 赛事",
                platform: dict["source"] as? String ?? "", location: dict["displayCity"] as? String ?? "地点待公布",
                prize: dict["prize"] as? String ?? "", participants: dict["participants"] as? Int ?? 0, tags: dict["tags"] as? [String] ?? [])
        }
        let cities = (region["cities"] as? [[String: Any]] ?? []).compactMap { city -> CompetitionCity? in
            guard let key = city["city"] as? String, let name = city["name_zh"] as? String else { return nil }
            return CompetitionCity(key: key, name: name, count: city["count"] as? Int ?? 0)
        }
        let regions = [CompetitionRegion(key: "China", name: "中国", cities: cities)]
        // A verified Chinese city can legitimately have no events; error/global pages cannot replace it.
        let current = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page" })?.value ?? "1") ?? 1
        var next: URL?
        let links = try NSRegularExpression(pattern: #"href="([^"]+)""#)
        for match in links.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range(at: 1), in: html),
                  let candidate = URL(string: String(html[range]).replacingOccurrences(of: "&amp;", with: "&"), relativeTo: url)?.absoluteURL,
                  CompetitionSource.isChinaFeed(candidate), candidate.path == url.path,
                  URLComponents(url: candidate, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page" })?.value == String(current + 1) else { continue }
            next = candidate; break
        }
        return CompetitionFeed(items: items, regions: regions, nextURL: next, fetchedAt: now)
    }
    static func detail(html: String, base: OfficialCompetition, now: Date = Date()) throws -> OfficialCompetition {
        let objects = try objects(in: html)
        guard let dict = objects.compactMap({ $0["competition"] as? [String: Any] }).first(where: { $0["id"] as? String == base.id && $0["startDate"] != nil }) else { throw CompetitionLoadError.formatChanged }
        var item = base
        item.start = CompetitionDates.parse(dict["startDate"] as? String)
        item.end = CompetitionDates.parse(dict["closeDate"] as? String)
        item.signupStatus = dict["signupStatus"] as? Int
        item.signupLink = CompetitionSource.safeURL(dict["signupUrl"] as? String)?.absoluteString
        item.organizer = (dict["providers"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: "、")
        if let location = dict["location"] as? String, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { item.location = location }
        item.prize = dict["prize"] as? String ?? base.prize
        item.participants = (dict["participants"] as? [String: Any])?["teams"] as? Int ?? base.participants
        item.fetchedAt = now
        return item
    }
}

enum CompetitionLoadError: LocalizedError {
    case unavailable, formatChanged
    var errorDescription: String? {
        switch self {
        case .unavailable: return "赛事来源暂时无法连接，请稍后重试。"
        case .formatChanged: return "赛事来源暂时无法读取，可打开来源页面查看。"
        }
    }
}
