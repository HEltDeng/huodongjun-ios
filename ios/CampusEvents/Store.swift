import SwiftUI
import Observation

@Observable @MainActor
final class AppStore {
    private(set) var state: AppState
    var error: String?
    var toast: String?
    private let fileURL: URL
    private let schedulesNotifications: Bool
    var profile: StudentProfile { state.profile }
    var space: ActivitySpace { state.settings.activeSpace }
    var school: School { School.named(state.settings.activeSchoolID) }
    var contextID: String { space.rawValue + ":" + school.id }
    var schoolVerified: Bool { SpaceRules.verifiedSchools(state).contains(school.id) }
    var scopedEvents: [CampusEvent] { state.events.filter { SpaceRules.inCurrentSpace($0, state: state) } }
    var events: [CampusEvent] { scopedEvents.filter { $0.published && !$0.cancelled }.sorted { $0.start < $1.start } }
    var notices: [ActivityNotice] { state.notices.filter { notice in notice.eventID.flatMap(event) != nil } }
    var unread: Int { notices.filter { !$0.read }.count }
    var conversations: [CampusEvent] { scopedEvents.filter { SpaceRules.canDiscuss($0, state: state) } }

    init(fileURL: URL? = nil) {
        let testID = ProcessInfo.processInfo.environment["UITEST_STORE_ID"].flatMap(UUID.init(uuidString:))
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: testID.map { "test-\($0.uuidString).json" } ?? "campus-events-v1.json")
        schedulesNotifications = fileURL == nil && testID == nil
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                state = try JSONDecoder().decode(AppState.self, from: Data(contentsOf: self.fileURL))
            } else { state = AppState(events: CampusEvent.examples()) }
        } catch {
            state = AppState(events: CampusEvent.examples())
            self.error = "本机数据暂时无法读取，原始文件已保留。"
            try? FileManager.default.copyItem(at: self.fileURL, to: self.fileURL.deletingPathExtension().appendingPathExtension("backup-\(UUID().uuidString).json"))
        }
        if state.spaceSettings == nil {
            state.settings = SpaceSettings(activeSchoolID: School.all.map(\.id).contains(state.profile.schoolID) ? state.profile.schoolID : "csust")
        }
        if !state.settings.demoSeedsAdded || state.settings.demoContentRevision == nil {
            let ids = Set(state.events.map(\.id))
            let examples = CampusEvent.expandedExamples()
            // Only refresh unbooked built-in samples; user events and bookings stay intact.
            for i in state.events.indices where state.events[i].hostID == nil && !state.registrations.contains(where: { $0.eventID == state.events[i].id }) {
                if let example = examples.first(where: { $0.id == state.events[i].id }) {
                    state.events[i].start = example.start
                    state.events[i].end = example.end
                    state.events[i].deadline = example.deadline
                }
            }
            state.events.append(contentsOf: examples.filter { !ids.contains($0.id) })
            for i in state.events.indices where state.events[i].cover == "tech" && state.events[i].interestTags == nil { state.events[i].interestTags = [.ai, .technology, .academic] }
            state.settings.demoSeedsAdded = true
            state.settings.demoContentRevision = 1
        }
        state.version = 2
    }
    @discardableResult func update(_ action: (inout AppState) throws -> Void) -> Bool {
        do {
            var next = state
            try action(&next)
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            state = next
            if schedulesNotifications { RecommendationNotifications.schedule(state: next) }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func event(_ id: UUID) -> CampusEvent? { scopedEvents.first { $0.id == id } }
    func registration(_ id: UUID) -> Registration? { state.registrations.last { $0.eventID == id && $0.studentID == profile.id && $0.status.active } }
    func count(_ event: CampusEvent) -> Int { event.baseAttendees + state.registrations.filter { $0.eventID == event.id && [.confirmed, .checkedIn].contains($0.status) }.count }
    func eligible(_ event: CampusEvent) -> Bool { SpaceRules.canRegister(event, state: state) }
    func ranked(_ events: [CampusEvent]) -> [CampusEvent] {
        events.filter { eligible($0) }.sorted {
            let a = SpaceRules.recommendationScore($0, state: state), b = SpaceRules.recommendationScore($1, state: state)
            return a == b ? $0.start < $1.start : a > b
        }
    }
    func switchSpace(_ space: ActivitySpace) { update { $0.settings.activeSpace = space } }
    func selectSchool(_ id: String) {
        guard School.all.map(\.id).contains(id) else { return }
        update { state in
            state.settings.activeSchoolID = id
            state.settings.activeSpace = .campus
            if let member = state.settings.memberships.first(where: { $0.schoolID == id && $0.status == .demoVerified }) {
                state.profile.schoolID = id; state.profile.studentNumber = member.studentNumber; state.profile.college = member.college
            }
        }
    }
    @discardableResult func verifyDemo(schoolID: String, number: String, college: String, status: VerificationStatus) -> Bool {
        update { state in
            let number = number.trimmingCharacters(in: .whitespacesAndNewlines)
            let college = college.trimmingCharacters(in: .whitespacesAndNewlines)
            guard School.all.map(\.id).contains(schoolID), !number.isEmpty, !college.isEmpty else { throw EventError.invalid("请填写学号和学院。") }
            state.settings.memberships.removeAll { $0.schoolID == schoolID }
            state.settings.memberships.append(SchoolMembership(schoolID: schoolID, studentNumber: number, college: college, status: status))
            if status == .demoVerified {
                state.settings.activeSchoolID = schoolID; state.settings.activeSpace = .campus
                state.profile.schoolID = schoolID; state.profile.studentNumber = number; state.profile.college = college
            }
        }
    }
    func enter(consent: Bool) { update { $0.onboarded = true; $0.consented = consent; if !consent { $0.settings.activeSpace = .city; $0.settings.setupCompleted = true } } }
    func favorite(_ id: UUID) { guard event(id) != nil else { return }; update { if $0.favorites.contains(id) { $0.favorites.remove(id) } else { $0.favorites.insert(id) } } }
    func follow(_ host: String) { update { if $0.followedHosts.contains(host) { $0.followedHosts.remove(host) } else { $0.followedHosts.insert(host) } } }
    func register(_ event: CampusEvent) -> Bool {
        update { state in
            guard let current = state.events.first(where: { $0.id == event.id }), SpaceRules.inCurrentSpace(current, state: state) else { throw EventError.invalid("请先进入该活动所属空间并验证学校身份。") }
            try EventRules.register(event: current, state: &state)
        }
    }
    func cancel(_ registration: Registration) { guard event(registration.eventID) != nil else { return }; update { try EventRules.cancel(registrationID: registration.id, state: &$0) } }
    func publish(_ event: CampusEvent) -> Bool {
        update { state in
            let previous = state.events.first(where: { $0.id == event.id })
            guard state.consented && state.onboarded && state.profile.complete else { throw EventError.invalid("请先完善个人资料并同意服务说明。") }
            try EventRules.validate(event, allowPastStart: previous?.start == event.start)
            guard SpaceRules.verifiedSchools(state).contains(event.schoolID), event.hostID == state.profile.id, previous == nil || previous?.hostID == state.profile.id else { throw EventError.invalid("请先验证主办学校身份，只能编辑自己发布的活动。") }
            if let previous {
                guard previous.space == event.space, previous.schoolID == event.schoolID, previous.audienceSchoolIDs == event.audienceSchoolIDs else { throw EventError.invalid("发布后不能更换空间或报名学校。请另建活动，保护已有报名和讨论。") }
            }
            if let index = state.events.firstIndex(where: { $0.id == event.id }) {
                let active = state.registrations.filter { $0.eventID == event.id && [.confirmed, .checkedIn].contains($0.status) }.count
                guard event.capacity >= event.baseAttendees + active else { throw EventError.invalid("人数上限不能小于已报名人数。") }
                state.events[index] = event
            } else {
                state.events.append(event)
                if SpaceRules.shouldRecommend(event, state: state), event.hostID != state.profile.id {
                    state.notices.insert(ActivityNotice(title: "你可能感兴趣", body: event.title, eventID: event.id, recommendation: true), at: 0)
                }
            }
            state.settings.activeSpace = event.space; state.settings.activeSchoolID = event.schoolID
        }
    }
    func approve(_ registration: Registration, event: CampusEvent) {
        update { state in
            guard let current = state.events.first(where: { $0.id == event.id }), SpaceRules.inCurrentSpace(current, state: state), current.hostID == state.profile.id, SpaceRules.verifiedSchools(state).contains(current.schoolID), registration.eventID == current.id, !current.cancelled, let i = state.registrations.firstIndex(where: { $0.id == registration.id }), state.registrations[i].eventID == current.id, [.pending, .waitlisted].contains(state.registrations[i].status) else { throw EventError.invalid("当前报名不能审核。") }
            let schoolID = state.registrations[i].schoolID ?? current.schoolID
            guard current.space == .campus ? schoolID == current.schoolID : current.audienceSchoolIDs.isEmpty || current.audienceSchoolIDs.contains(schoolID) else { throw EventError.invalid("该报名不在开放学校范围内。") }
            let count = current.baseAttendees + state.registrations.filter { $0.eventID == current.id && [.confirmed, .checkedIn].contains($0.status) }.count
            guard count < current.capacity else { throw EventError.invalid("名额已满，请先增加活动人数上限。") }
            state.registrations[i].status = .confirmed
            state.notices.insert(ActivityNotice(title: "报名已通过", body: "「\(current.title)」期待你的到来。", eventID: current.id), at: 0)
        }
    }
    func checkIn(_ code: String, event: CampusEvent) -> Bool { update { try EventRules.checkIn(code: code, eventID: event.id, state: &$0) } }
    func postMessage(_ text: String, event: CampusEvent) -> Bool {
        update { state in
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty && body.count <= 2000 else { throw EventError.invalid("请输入 1～2000 字的内容。") }
            guard let current = state.events.first(where: { $0.id == event.id }), SpaceRules.canDiscuss(current, state: state) else { throw EventError.invalid("请先完成活动报名，再参与对应空间的讨论。") }
            state.messages.append(DiscussionMessage(eventID: current.id, author: state.profile.name, body: body))
        }
    }
    func markCurrentNoticesRead() {
        let ids = Set(notices.map(\.id))
        update { state in for i in state.notices.indices where ids.contains(state.notices[i].id) { state.notices[i].read = true } }
    }
    func previewRecommendations() -> Int {
        let candidates = ranked(events).filter { SpaceRules.shouldRecommend($0, state: state) && !state.settings.recommendedEventIDs.contains($0.id) }.prefix(3)
        guard !candidates.isEmpty else { return 0 }
        return update { state in
            for event in candidates {
                state.notices.insert(ActivityNotice(title: "\(event.space.title)兴趣精选", body: event.title, eventID: event.id, recommendation: true), at: 0)
                state.settings.recommendedEventIDs.insert(event.id)
            }
        } ? candidates.count : 0
    }
    func cancelEvent(_ event: CampusEvent) {
        update { state in
            guard let i = state.events.firstIndex(where: { $0.id == event.id }), SpaceRules.inCurrentSpace(state.events[i], state: state), state.events[i].hostID == state.profile.id, SpaceRules.verifiedSchools(state).contains(state.events[i].schoolID) else { throw EventError.invalid("只能取消自己的活动。") }
            guard !state.registrations.contains(where: { $0.eventID == event.id && $0.status == .checkedIn }) else { throw EventError.invalid("已有签到记录的活动需通过后端审核撤销。") }
            state.events[i].cancelled = true
            for j in state.registrations.indices where state.registrations[j].eventID == event.id { state.registrations[j].status = .cancelled }
            state.notices.insert(ActivityNotice(title: "活动已取消", body: event.title, eventID: event.id), at: 0)
        }
    }
}
