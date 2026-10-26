import XCTest
import UIKit
@testable import CampusEvents

final class EventRulesTests: XCTestCase {
    func testPosterAssetsAreBundled() {
        for name in ["weekend", "music", "tech"] { XCTAssertNotNil(UIImage(named: name), "Missing bundled poster: \(name)") }
    }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func state() -> AppState {
        var state = AppState()
        state.onboarded = true; state.consented = true
        state.settings.memberships = [SchoolMembership(schoolID: "csust", studentNumber: "DEMO2026001", college: "测试学院", status: .demoVerified)]
        state.settings.setupCompleted = true
        return state
    }
    func event(owner: UUID? = nil) -> CampusEvent {
        CampusEvent(title: "测试活动", summary: "", description: "", category: .study, location: "实验楼", start: now.addingTimeInterval(600), end: now.addingTimeInterval(3600), deadline: now.addingTimeInterval(300), hostID: owner, host: "主办方", cover: "tech", capacity: 1, creditHundredths: 50)
    }
    func testRegistrationIsIdempotent() throws {
        var data = state(); let e = event()
        try EventRules.register(event: e, state: &data, now: now)
        let ticket = data.registrations[0].ticketCode
        try EventRules.register(event: e, state: &data, now: now)
        XCTAssertEqual(data.registrations.count, 1)
        XCTAssertEqual(data.registrations[0].ticketCode, ticket)
        XCTAssertEqual(data.notices.count, 1)
    }
    func testFullCapacityCreatesWaitlistOrRejects() throws {
        var data = state(); var e = event(); e.baseAttendees = 1
        try EventRules.register(event: e, state: &data, now: now)
        XCTAssertEqual(data.registrations[0].status, .waitlisted)
        data.registrations = []; e.allowWaitlist = false
        XCTAssertThrowsError(try EventRules.register(event: e, state: &data, now: now))
        XCTAssertTrue(data.registrations.isEmpty)
    }
    func testApprovalDoesNotIssueAdmittedStatus() throws {
        var data = state(); var e = event(); e.requiresApproval = true
        try EventRules.register(event: e, state: &data, now: now)
        XCTAssertEqual(data.registrations[0].status, .pending)
    }
    func testRegistrationRejectsExpiredCrossSchoolAndCancelled() {
        var data = state(); var e = event()
        XCTAssertThrowsError(try EventRules.register(event: e, state: &data, now: e.deadline))
        e.schoolID = "other"
        XCTAssertThrowsError(try EventRules.register(event: e, state: &data, now: now))
        e.schoolID = "csust"; e.cancelled = true
        XCTAssertThrowsError(try EventRules.register(event: e, state: &data, now: now))
        XCTAssertTrue(data.registrations.isEmpty)
    }
    func testIdentityAndConsentRequired() {
        var data = state(); data.consented = false
        XCTAssertThrowsError(try EventRules.register(event: event(), state: &data, now: now))
        data.consented = true; data.profile.college = "   "
        XCTAssertThrowsError(try EventRules.register(event: event(), state: &data, now: now))
    }
    func testCancellationInvalidatesTicketAndReregistrationRotatesIt() throws {
        var data = state(); let e = event(owner: data.profile.id); data.events = [e]
        try EventRules.register(event: e, state: &data, now: now)
        let old = data.registrations[0]
        try EventRules.cancel(registrationID: old.id, state: &data)
        XCTAssertThrowsError(try EventRules.checkIn(code: "huodongjun:local-ticket:\(old.ticketCode)", eventID: e.id, state: &data, now: now))
        try EventRules.register(event: e, state: &data, now: now)
        XCTAssertNotEqual(data.registrations.last?.ticketCode, old.ticketCode)
    }
    func testCheckInRequiresOwnerAndCorrectEvent() throws {
        var data = state(); let e = event(owner: UUID()); data.events = [e]
        try EventRules.register(event: e, state: &data, now: now)
        let code = "huodongjun:local-ticket:\(data.registrations[0].ticketCode)"
        XCTAssertThrowsError(try EventRules.checkIn(code: code, eventID: e.id, state: &data, now: now))
        data.events[0].hostID = data.profile.id
        XCTAssertThrowsError(try EventRules.checkIn(code: code, eventID: UUID(), state: &data, now: now))
        XCTAssertThrowsError(try EventRules.checkIn(code: "forged", eventID: e.id, state: &data, now: now))
    }
    func testCheckInIsIdempotentAndSnapshotsCredit() throws {
        var data = state(); var e = event(owner: data.profile.id); e.creditMode = .automatic; data.events = [e]
        try EventRules.register(event: e, state: &data, now: now)
        let code = "huodongjun:local-ticket:\(data.registrations[0].ticketCode)"
        try EventRules.checkIn(code: code, eventID: e.id, state: &data, now: now)
        data.events[0].creditHundredths = 200
        try EventRules.checkIn(code: code, eventID: e.id, state: &data, now: now.addingTimeInterval(10))
        XCTAssertEqual(data.registrations[0].creditHundredths, 50)
        XCTAssertTrue(data.registrations[0].creditApproved)
        XCTAssertEqual(data.registrations[0].checkedInAt, now)
        XCTAssertThrowsError(try EventRules.cancel(registrationID: data.registrations[0].id, state: &data))
    }
    func testCheckInTimeWindowAndPendingStatus() throws {
        var data = state(); var e = event(owner: data.profile.id); data.events = [e]
        try EventRules.register(event: e, state: &data, now: now)
        let code = "huodongjun:local-ticket:\(data.registrations[0].ticketCode)"
        XCTAssertThrowsError(try EventRules.checkIn(code: code, eventID: e.id, state: &data, now: e.start.addingTimeInterval(-1801)))
        XCTAssertThrowsError(try EventRules.checkIn(code: code, eventID: e.id, state: &data, now: e.end.addingTimeInterval(1)))
        data.registrations[0].status = .pending
        XCTAssertThrowsError(try EventRules.checkIn(code: code, eventID: e.id, state: &data, now: now))
        data.registrations[0].status = .confirmed; e.cancelled = true; data.events = [e]
        XCTAssertThrowsError(try EventRules.checkIn(code: code, eventID: e.id, state: &data, now: now))
    }
    func testEventValidationAndSafeGroupLinks() throws {
        var e = event(); try EventRules.validate(e, now: now)
        e.end = e.start; XCTAssertThrowsError(try EventRules.validate(e, now: now))
        e = event(); e.deadline = e.end; XCTAssertThrowsError(try EventRules.validate(e, now: now))
        for unsafe in ["javascript:alert(1)", "http://example.com", "file:///etc/passwd", "https://user:password@example.com", "weixin://"] { XCTAssertNil(EventRules.safeGroupURL(unsafe)) }
        XCTAssertEqual(EventRules.safeGroupURL("https://example.com/group")?.host, "example.com")
    }
    @MainActor func testPersistenceAcrossStoreInstances() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appending(path: "state.json")
        let first = AppStore(fileURL: url)
        first.enter(consent: true)
        XCTAssertTrue(first.verifyDemo(schoolID: "csust", number: "DEMO2026001", college: "测试学院", status: .demoVerified))
        let event = try XCTUnwrap(first.events.first)
        XCTAssertTrue(first.register(event))
        first.favorite(event.id)
        let second = AppStore(fileURL: url)
        XCTAssertTrue(second.state.consented)
        XCTAssertNotNil(second.registration(event.id))
        XCTAssertTrue(second.state.favorites.contains(event.id))
        XCTAssertEqual(first.profile.id, second.profile.id)
    }

    @MainActor func testPublishEditGroupAndReload() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        store.enter(consent: true)
        XCTAssertTrue(store.verifyDemo(schoolID: "csust", number: "DEMO2026001", college: "测试学院", status: .demoVerified))
        var draft = event(owner: store.profile.id)
        draft.start = Date().addingTimeInterval(7200)
        draft.end = draft.start.addingTimeInterval(3600)
        draft.deadline = draft.start.addingTimeInterval(-1800)
        draft.group.link = "https://example.com/campus-demo"
        XCTAssertTrue(store.publish(draft))
        XCTAssertTrue(store.register(draft))
        draft.title = "修改后的活动"
        XCTAssertTrue(store.publish(draft))
        let restored = AppStore(fileURL: url)
        XCTAssertEqual(restored.event(draft.id)?.title, draft.title)
        XCTAssertEqual(restored.event(draft.id)?.group.link, draft.group.link)
        XCTAssertNotNil(restored.registration(draft.id))
    }

    @MainActor func testPublishingCannotClaimAnotherHostsEvent() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        store.enter(consent: true)
        XCTAssertTrue(store.verifyDemo(schoolID: "csust", number: "DEMO2026001", college: "测试学院", status: .demoVerified))
        var seed = try XCTUnwrap(store.events.first)
        seed.hostID = store.profile.id
        XCTAssertFalse(store.publish(seed))
        XCTAssertNil(store.event(seed.id)?.hostID)
    }

    @MainActor func testRegistrationUsesLatestStoredEvent() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        store.enter(consent: true)
        XCTAssertTrue(store.verifyDemo(schoolID: "csust", number: "DEMO2026001", college: "测试学院", status: .demoVerified))
        let stale = try XCTUnwrap(store.events.first)
        XCTAssertTrue(store.update { state in
            let index = state.events.firstIndex(where: { $0.id == stale.id })!
            state.events[index].cancelled = true
        })
        XCTAssertFalse(store.register(stale))
        XCTAssertNil(store.registration(stale.id))
    }
}
