import SwiftUI
import Observation

@Observable @MainActor
final class AppStore {
    private(set) var state: AppState
    var error: String?
    var toast: String?
    private let fileURL: URL
    var profile: StudentProfile { state.profile }
    var events: [CampusEvent] { state.events.filter { $0.schoolID == profile.schoolID && $0.published && !$0.cancelled }.sorted { $0.start < $1.start } }
    var unread: Int { state.notices.filter { !$0.read }.count }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "campus-events-v1.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                state = try JSONDecoder().decode(AppState.self, from: Data(contentsOf: self.fileURL))
            } else {
                state = AppState(events: CampusEvent.examples())
            }
        } catch {
            state = AppState(events: CampusEvent.examples())
            self.error = "本机数据暂时无法读取。原始文件已保留，请在设置中查看。"
            try? FileManager.default.copyItem(at: self.fileURL, to: self.fileURL.deletingPathExtension().appendingPathExtension("backup-\(UUID().uuidString).json"))
        }
    }
    @discardableResult func update(_ action: (inout AppState) throws -> Void) -> Bool {
        do {
            var next = state
            try action(&next)
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            state = next
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func event(_ id: UUID) -> CampusEvent? { state.events.first { $0.id == id } }
    func registration(_ id: UUID) -> Registration? { state.registrations.last { $0.eventID == id && $0.studentID == profile.id && $0.status.active } }
    func count(_ event: CampusEvent) -> Int { event.baseAttendees + state.registrations.filter { $0.eventID == event.id && [.confirmed, .checkedIn].contains($0.status) }.count }
    func enter(consent: Bool) { update { $0.onboarded = true; $0.consented = consent } }
    func favorite(_ id: UUID) { update { if $0.favorites.contains(id) { $0.favorites.remove(id) } else { $0.favorites.insert(id) } } }
    func follow(_ host: String) { update { if $0.followedHosts.contains(host) { $0.followedHosts.remove(host) } else { $0.followedHosts.insert(host) } } }
    func register(_ event: CampusEvent) -> Bool { update { try EventRules.register(event: event, state: &$0) } }
    func cancel(_ registration: Registration) { update { try EventRules.cancel(registrationID: registration.id, state: &$0) } }
    func publish(_ event: CampusEvent) -> Bool {
        update { state in
            try EventRules.validate(event)
            guard event.hostID == state.profile.id else { throw EventError.invalid("只能编辑自己发布的活动。") }
            if let index = state.events.firstIndex(where: { $0.id == event.id }) {
                let active = state.registrations.filter { $0.eventID == event.id && [.confirmed, .checkedIn].contains($0.status) }.count
                guard event.capacity >= event.baseAttendees + active else { throw EventError.invalid("人数上限不能小于已报名人数。") }
                state.events[index] = event
            } else { state.events.append(event) }
        }
    }
    func approve(_ registration: Registration, event: CampusEvent) {
        update { state in
            guard event.hostID == state.profile.id, let i = state.registrations.firstIndex(where: { $0.id == registration.id }), [.pending, .waitlisted].contains(state.registrations[i].status) else { throw EventError.invalid("当前报名不能审核。") }
            let count = event.baseAttendees + state.registrations.filter { $0.eventID == event.id && [.confirmed, .checkedIn].contains($0.status) }.count
            guard count < event.capacity else { throw EventError.invalid("名额已满，请先增加活动人数上限。") }
            state.registrations[i].status = .confirmed
            state.notices.insert(ActivityNotice(title: "报名已通过", body: "「\(event.title)」期待你的到来。", eventID: event.id), at: 0)
        }
    }
    func checkIn(_ code: String, event: CampusEvent) -> Bool { update { try EventRules.checkIn(code: code, eventID: event.id, state: &$0) } }
    func cancelEvent(_ event: CampusEvent) {
        update { state in
            guard event.hostID == state.profile.id, let i = state.events.firstIndex(where: { $0.id == event.id }) else { throw EventError.invalid("只能取消自己的活动。") }
            guard !state.registrations.contains(where: { $0.eventID == event.id && $0.status == .checkedIn }) else { throw EventError.invalid("已有签到记录的活动需通过后端审核撤销。") }
            state.events[i].cancelled = true
            for j in state.registrations.indices where state.registrations[j].eventID == event.id { state.registrations[j].status = .cancelled }
            state.notices.insert(ActivityNotice(title: "活动已取消", body: event.title, eventID: event.id), at: 0)
        }
    }
}
