import Foundation

enum Category: String, Codable, CaseIterable, Identifiable {
    case all = "全部", culture = "文艺生活", study = "学术科技", sport = "运动户外", volunteer = "志愿公益"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .all: "square.grid.2x2"; case .culture: "music.note"; case .study: "lightbulb"; case .sport: "figure.walk"; case .volunteer: "heart" }
    }
}
enum Campus: String, Codable, CaseIterable, Identifiable {
    case all = "全部校区", yuntang = "云塘校区", jinpenling = "金盆岭校区"
    var id: String { rawValue }
}
enum RegistrationStatus: String, Codable {
    case confirmed = "报名成功", pending = "待审核", waitlisted = "候补中", checkedIn = "已签到", cancelled = "已取消"
    var active: Bool { self != .cancelled }
}
enum CreditMode: String, Codable, CaseIterable { case review = "老师审核后计入", automatic = "签到后自动计入" }

struct StudentProfile: Codable, Equatable {
    var id = UUID()
    var name = "体验同学"
    var studentNumber = "DEMO2026001"
    var college = "计算机与通信工程学院"
    var bio = "一起发现校园里的好活动。"
    var avatarData: Data? = nil
    var birthday: Date? = nil
    var schoolID = "csust"
    var complete: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !college.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
struct EventGroup: Codable, Equatable {
    var name = "活动交流群"
    var platform = "微信"
    var notice = "入群后请将群昵称改为姓名，方便活动通知。"
    var imageData: Data? = nil
    var link = ""
    var membersOnly = true
    var available: Bool { imageData != nil || !link.isEmpty }
}
struct CampusEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var schoolID = "csust"
    var title: String
    var summary: String
    var description: String
    var category: Category
    var campus: Campus = .yuntang
    var location: String
    var start: Date
    var end: Date
    var deadline: Date
    var hostID: UUID? = nil
    var host: String
    var cover: String
    var imageData: Data? = nil
    var capacity = 60
    var baseAttendees = 0
    var requiresApproval = false
    var allowWaitlist = true
    var creditHundredths = 0
    var creditMode: CreditMode = .review
    var group = EventGroup()
    var published = true
    var cancelled = false
    var agenda = [String]()
    var creditText: String { String(format: "%.2f", Double(creditHundredths) / 100).replacingOccurrences(of: ".00", with: "") }
    var shareText: String { "邀请你参加「\(title)」\n长沙理工大学 · \(campus.rawValue)\n\(start.formatted(date: .abbreviated, time: .shortened))\n\(location)" }
}
struct Registration: Identifiable, Codable, Equatable {
    var id = UUID()
    var eventID: UUID
    var studentID: UUID
    var status: RegistrationStatus
    var createdAt = Date()
    var checkedInAt: Date? = nil
    // Local preview ticket. This is deliberately not a production admission credential.
    var ticketCode = UUID().uuidString
    var creditHundredths = 0
    var creditApproved = false
}
struct ActivityNotice: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var eventID: UUID? = nil
    var date = Date()
    var read = false
}
struct DiscussionMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var eventID: UUID
    var author: String
    var body: String
    var date = Date()
}
struct AppState: Codable {
    var version = 1
    var profile = StudentProfile()
    var onboarded = false
    var consented = false
    var events = [CampusEvent]()
    var registrations = [Registration]()
    var favorites = Set<UUID>()
    var followedHosts = Set<String>()
    var notices = [ActivityNotice]()
    var messages = [DiscussionMessage]()
}
enum EventError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let text): text } }
}

enum EventRules {
    static func validate(_ event: CampusEvent, now: Date = Date(), allowPastStart: Bool = false) throws {
        guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EventError.invalid("请填写活动名称。") }
        guard !event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EventError.invalid("请填写活动地点。") }
        guard event.end > event.start else { throw EventError.invalid("结束时间必须晚于开始时间。") }
        guard event.deadline <= event.start else { throw EventError.invalid("报名截止时间不能晚于活动开始时间。") }
        guard allowPastStart || event.start > now else { throw EventError.invalid("请选择未来的活动开始时间。") }
        guard (1...10000).contains(event.capacity) else { throw EventError.invalid("人数上限应在 1～10000 人之间。") }
        guard event.capacity >= event.baseAttendees else { throw EventError.invalid("人数上限不能小于已报名人数。") }
        guard event.creditHundredths >= 0 && event.creditHundredths <= 10000 else { throw EventError.invalid("综测分应在 0～100 分之间。") }
        if !event.group.link.isEmpty && safeGroupURL(event.group.link) == nil { throw EventError.invalid("群链接仅支持完整的 HTTPS 链接。") }
    }
    static func safeGroupURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
    static func register(event: CampusEvent, state: inout AppState, now: Date = Date()) throws {
        guard state.consented && state.onboarded && state.profile.complete else { throw EventError.invalid("请先完善校园身份，再报名活动。") }
        guard event.schoolID == state.profile.schoolID && event.published && !event.cancelled else { throw EventError.invalid("该活动当前不可报名。") }
        guard now < event.deadline else { throw EventError.invalid("报名已截止。") }
        if state.registrations.contains(where: { $0.eventID == event.id && $0.studentID == state.profile.id && $0.status.active }) { return }
        let occupied = event.baseAttendees + state.registrations.filter { $0.eventID == event.id && [.confirmed, .checkedIn].contains($0.status) }.count
        let status: RegistrationStatus
        if occupied >= event.capacity {
            guard event.allowWaitlist else { throw EventError.invalid("活动名额已满。") }
            status = .waitlisted
        } else { status = event.requiresApproval ? .pending : .confirmed }
        state.registrations.append(Registration(eventID: event.id, studentID: state.profile.id, status: status))
        state.notices.insert(ActivityNotice(title: status.rawValue, body: "「\(event.title)」\(status == .confirmed ? "已加入你的活动。" : "的报名状态已更新。")", eventID: event.id), at: 0)
    }
    static func cancel(registrationID: UUID, state: inout AppState) throws {
        guard let index = state.registrations.firstIndex(where: { $0.id == registrationID && $0.studentID == state.profile.id }) else { throw EventError.invalid("未找到报名记录。") }
        guard state.registrations[index].status != .checkedIn else { throw EventError.invalid("已签到的活动无法取消报名，请联系主办方。") }
        state.registrations[index].status = .cancelled
        let eventID = state.registrations[index].eventID
        if let event = state.events.first(where: { $0.id == eventID }), !event.requiresApproval {
            let occupied = event.baseAttendees + state.registrations.filter { $0.eventID == eventID && [.confirmed, .checkedIn].contains($0.status) }.count
            if occupied < event.capacity, let next = state.registrations.indices.filter({ state.registrations[$0].eventID == eventID && state.registrations[$0].status == .waitlisted }).min(by: { state.registrations[$0].createdAt < state.registrations[$1].createdAt }) {
                state.registrations[next].status = .confirmed
            }
        }
    }
    static func checkIn(code: String, eventID: UUID, state: inout AppState, now: Date = Date()) throws {
        guard let event = state.events.first(where: { $0.id == eventID }), event.hostID == state.profile.id else { throw EventError.invalid("仅活动发起人可核销本机体验票。") }
        guard event.published && !event.cancelled else { throw EventError.invalid("活动当前不可签到。") }
        guard now >= event.start.addingTimeInterval(-30 * 60) && now <= event.end else { throw EventError.invalid("签到在活动开始前 30 分钟至结束期间开放。") }
        guard let index = state.registrations.firstIndex(where: { $0.eventID == eventID && "huodongjun:local-ticket:\($0.ticketCode)" == code.trimmingCharacters(in: .whitespacesAndNewlines) }) else { throw EventError.invalid("不是这场活动的有效体验票。") }
        if state.registrations[index].status == .checkedIn { return }
        guard state.registrations[index].status == .confirmed else { throw EventError.invalid("只有报名成功的凭证可以签到。") }
        state.registrations[index].status = .checkedIn
        state.registrations[index].checkedInAt = now
        state.registrations[index].creditHundredths = event.creditHundredths
        state.registrations[index].creditApproved = event.creditMode == .automatic
    }
}

extension CampusEvent {
    static func examples(now: Date = Date()) -> [CampusEvent] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = calendar.startOfDay(for: now)
        func date(_ day: Int, _ hour: Int) -> Date { calendar.date(byAdding: .hour, value: day * 24 + hour, to: today)! }
        return [
            CampusEvent(title: "把周末交给自然", summary: "校园漫步 · 秋日摄影 · 认识新朋友", description: "在忙碌的课表之外，给自己一个慢下来的下午。\n\n我们会沿着校园步道散步、观察秋天的颜色，用手机或相机记录平时忽略的小风景。不需要摄影基础，也不用准备专业设备，带着好奇心来就好。\n\n集合后会分成小组自由探索，最后一起分享今天最喜欢的一张照片。建议穿舒适的鞋子，自备饮用水。遇雨将在活动页更新安排。", category: .sport, location: "云塘校区 · 图书馆前坪集合", start: date(1, 15), end: date(1, 17), deadline: date(1, 14), host: "校园漫游计划", cover: "weekend", capacity: 60, baseAttendees: 26, creditHundredths: 50, agenda: ["15:00  集合与破冰", "15:20  校园漫步与自由拍摄", "16:30  照片分享与合影"]),
            CampusEvent(title: "下课后，来一场草坪音乐会", summary: "把耳机摘下来，一起听见秋天", description: "熟悉的旋律、微凉的晚风，和同样喜欢音乐的你。\n\n校园乐队与独立唱作同学带来一场轻松的户外演出。欢迎自带野餐垫，和朋友一起坐下来听歌。\n\n活动结束请带走随身垃圾，一起爱护草坪。", category: .culture, location: "云塘校区 · 学生活动中心", start: date(2, 19), end: date(2, 21), deadline: date(2, 17), host: "长理音乐现场", cover: "music", capacity: 120, baseAttendees: 68, agenda: ["18:30  开放入场", "19:00  乐队现场", "20:30  自由点歌"]),
            CampusEvent(title: "IDEA LAB：把想法变成作品", summary: "一场给所有专业同学的创意工作坊", description: "你有没有一个一直想做、却还没开始的小项目？\n\n这次工作坊会带你从发现问题开始，画出第一个原型，再用简单工具把想法变成可以展示的作品。欢迎任何专业的同学，不要求编程经验。\n\n请携带充满电的笔记本电脑，提前十分钟到场。", category: .study, location: "云塘校区 · 综合实验楼", start: date(3, 14), end: date(3, 17), deadline: date(3, 12), host: "长理创意实验室", cover: "tech", capacity: 40, baseAttendees: 32, requiresApproval: true, creditHundredths: 100, agenda: ["14:00  灵感分享", "14:30  小组共创", "16:30  成果展示"]),
            CampusEvent(title: "周日一起，把校园变得更美", summary: "校园环保志愿活动", description: "从身边的小事开始，一起整理公共空间，宣传垃圾分类。活动提供必要的清洁工具，请穿着适合劳动的衣物。", category: .volunteer, campus: .jinpenling, location: "金盆岭校区 · 校门内集合", start: date(4, 9), end: date(4, 11), deadline: date(3, 20), host: "校园青年志愿者", cover: "weekend", capacity: 25, baseAttendees: 25, creditHundredths: 50, agenda: ["09:00  签到与工具领取", "09:15  分组行动", "10:45  整理与分享"])
        ]
    }
}
