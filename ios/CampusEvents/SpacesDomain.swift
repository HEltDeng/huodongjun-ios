import Foundation

enum ActivitySpace: String, Codable, CaseIterable, Identifiable {
    case campus, city
    var id: String { rawValue }
    var title: String { self == .campus ? "校园" : "长沙" }
    var symbol: String { self == .campus ? "building.2" : "building.2.crop.circle" }
}
struct School: Identifiable, Equatable {
    let id: String
    let name: String
    let shortName: String
    static let all = [School(id: "csust", name: "长沙理工大学", shortName: "长理"), School(id: "hnu", name: "湖南大学", shortName: "湖大"), School(id: "csu", name: "中南大学", shortName: "中南")]
    static func named(_ id: String) -> School { all.first { $0.id == id } ?? School(id: id, name: "未选择学校", shortName: "学校") }
}
enum VerificationStatus: String, Codable {
    case pending = "审核中", demoVerified = "演示已验证", rejected = "未通过"
}
struct SchoolMembership: Codable, Equatable, Identifiable {
    var schoolID: String
    var studentNumber: String
    var college: String
    var status: VerificationStatus
    var id: String { schoolID }
}
enum Interest: String, Codable, CaseIterable, Identifiable {
    case ai, technology, academic, art, sport, volunteer, career, startup, music, competition
    var id: String { rawValue }
    var title: String {
        switch self { case .ai: "人工智能"; case .technology: "科技竞赛"; case .academic: "学术讲座"; case .art: "艺术展演"; case .sport: "运动户外"; case .volunteer: "志愿公益"; case .career: "职业发展"; case .startup: "创新创业"; case .music: "音乐舞蹈"; case .competition: "文体比赛" }
    }
    var symbol: String {
        switch self { case .ai: "sparkles"; case .technology: "cpu"; case .academic: "graduationcap"; case .art: "paintpalette"; case .sport: "figure.walk"; case .volunteer: "heart"; case .career: "briefcase"; case .startup: "lightbulb"; case .music: "music.note"; case .competition: "trophy" }
    }
}
enum RecommendationFrequency: String, Codable, CaseIterable { case daily = "每日精选", weekly = "每周精选" }
struct SpaceSettings: Codable, Equatable {
    var activeSpace: ActivitySpace = .campus
    var activeSchoolID = "csust"
    var memberships = [SchoolMembership]()
    var interests = Set<Interest>()
    var campusRecommendations = true
    var cityRecommendations = false
    var frequency: RecommendationFrequency = .daily
    var setupCompleted = false
    var demoSeedsAdded = false
    var demoContentRevision: Int? = nil
    var interactionTourSeen: Bool? = nil
    var recommendedEventIDs = Set<UUID>()
}
struct EventAccess: Codable, Equatable {
    var space: ActivitySpace = .campus
    // Empty means all verified students in the city; campus is always schoolID-only.
    var audienceSchoolIDs = Set<String>()
}
extension AppState {
    var settings: SpaceSettings {
        get { spaceSettings ?? SpaceSettings() }
        set { spaceSettings = newValue }
    }
}
extension CampusEvent {
    var space: ActivitySpace { access?.space ?? .campus }
    var audienceSchoolIDs: Set<String> { access?.audienceSchoolIDs ?? [] }
    var topics: Set<Interest> {
        if let interestTags { return interestTags }
        switch category { case .study: return [.academic, .technology]; case .culture: return [.music, .art]; case .sport: return [.sport]; case .volunteer: return [.volunteer]; case .all: return [] }
    }
    var schoolName: String { School.named(schoolID).name }
    var locationContext: String { space == .city ? "长沙 · 跨校开放" : schoolName + (schoolID == "csust" ? " · " + campus.rawValue : "") }
    var audienceText: String {
        if space == .campus { return "仅\(schoolName)已验证学生" }
        return audienceSchoolIDs.isEmpty ? "长沙各高校已验证学生" : audienceSchoolIDs.sorted().map { School.named($0).name }.joined(separator: "、")
    }
    var scopeLabel: String { space == .campus ? "本校专属" : audienceSchoolIDs.isEmpty ? "长沙高校开放" : "指定高校开放" }
}
enum SpaceRules {
    static func verifiedSchools(_ state: AppState) -> Set<String> {
        Set(state.settings.memberships.filter { $0.status == .demoVerified && School.all.map(\.id).contains($0.schoolID) }.map(\.schoolID))
    }
    static func canAccess(_ event: CampusEvent, state: AppState) -> Bool {
        event.space == .city || verifiedSchools(state).contains(event.schoolID)
    }
    static func inCurrentSpace(_ event: CampusEvent, state: AppState) -> Bool {
        event.space == state.settings.activeSpace && (event.space == .city || event.schoolID == state.settings.activeSchoolID) && canAccess(event, state: state)
    }
    static func eligibleSchools(_ event: CampusEvent, state: AppState) -> Set<String> {
        let verified = verifiedSchools(state)
        if event.space == .campus { return verified.intersection([event.schoolID]) }
        return event.audienceSchoolIDs.isEmpty ? verified : verified.intersection(event.audienceSchoolIDs)
    }
    static func canRegister(_ event: CampusEvent, state: AppState) -> Bool { !eligibleSchools(event, state: state).isEmpty }
    static func membership(for event: CampusEvent, state: AppState) -> SchoolMembership? {
        let ids = eligibleSchools(event, state: state)
        return state.settings.memberships.first { $0.schoolID == state.settings.activeSchoolID && ids.contains($0.schoolID) } ?? state.settings.memberships.first { ids.contains($0.schoolID) }
    }
    static func canDiscuss(_ event: CampusEvent, state: AppState) -> Bool {
        inCurrentSpace(event, state: state) && !event.cancelled && ((event.hostID == state.profile.id && verifiedSchools(state).contains(event.schoolID)) || (canRegister(event, state: state) && state.registrations.contains { $0.eventID == event.id && $0.studentID == state.profile.id && [.confirmed, .checkedIn].contains($0.status) }))
    }
    static func recommendationScore(_ event: CampusEvent, state: AppState) -> Int { event.topics.intersection(state.settings.interests).count }
    static func shouldRecommend(_ event: CampusEvent, state: AppState, now: Date = Date()) -> Bool {
        event.published && !event.cancelled && (event.space == .city || event.schoolID == state.settings.activeSchoolID) && event.deadline > now && canRegister(event, state: state) && recommendationScore(event, state: state) > 0 && (event.space == .campus ? state.settings.campusRecommendations : state.settings.cityRecommendations)
    }
}
extension CampusEvent {
    static func expandedExamples(now: Date = Date()) -> [CampusEvent] {
        func make(_ id: String, _ title: String, _ school: String, _ space: ActivitySpace, _ category: Category, _ cover: String, _ topics: Set<Interest>, _ audience: Set<String> = []) -> CampusEvent {
            let calendar = Calendar.current
            let day = calendar.date(byAdding: .day, value: 2, to: now)!
            let start = calendar.date(bySettingHour: title.contains("夜") ? 19 : 14, minute: 0, second: 0, of: day)!
            var event = CampusEvent(schoolID: school, title: title, summary: space == .city ? "走出校园，遇见志同道合的人" : "把好奇心带进校园生活", description: "这是一场面向大学生的交流活动。带上你的想法，与同好一起探索、分享与合作。\n\n具体安排以活动通知为准。", category: category, location: space == .city ? "长沙 · 城市活动空间" : "校内学生活动室", start: start, end: start.addingTimeInterval(10800), deadline: start.addingTimeInterval(-3600), host: School.named(school).shortName + "同好计划", cover: cover, capacity: 80, baseAttendees: 18)
            event.id = UUID(uuidString: id)!
            event.access = EventAccess(space: space, audienceSchoolIDs: audience)
            event.interestTags = topics
            return event
        }
        return [
            make("56000000-0000-4000-8000-000000000001", "长沙高校 AI 共创夜", "csust", .city, .study, "tech", [.ai, .startup]),
            make("56000000-0000-4000-8000-000000000002", "机器人联赛 · 长理 × 湖大", "hnu", .city, .study, "tech", [.technology, .competition], ["csust", "hnu"]),
            make("56000000-0000-4000-8000-000000000003", "周末艺术共赏计划", "hnu", .city, .culture, "weekend", [.art], ["hnu", "csu"]),
            make("56000000-0000-4000-8000-000000000004", "湖大学术沙龙：从问题开始研究", "hnu", .campus, .study, "tech", [.academic, .ai]),
            make("56000000-0000-4000-8000-000000000005", "中南校园音乐分享会", "csu", .campus, .culture, "music", [.art, .music]),
            make("56000000-0000-4000-8000-000000000006", "长沙高校 · 落日音乐会", "csust", .city, .culture, "music", [.music, .art]),
            make("56000000-0000-4000-8000-000000000007", "一起走进长沙的周末", "csust", .city, .sport, "weekend", [.sport, .volunteer])
        ]
    }
}
