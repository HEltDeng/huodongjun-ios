import XCTest
@testable import CampusEvents

final class SpaceRulesTests: XCTestCase {
    func verifiedState() -> AppState {
        var state = AppState(events: CampusEvent.examples() + CampusEvent.expandedExamples())
        state.onboarded = true; state.consented = true
        state.settings.memberships = [SchoolMembership(schoolID: "csust", studentNumber: "DEMO123", college: "测试学院", status: .demoVerified)]
        state.settings.interests = [.ai, .technology]
        return state
    }
    func testSchoolNumberAloneDoesNotGrantSchoolAccess() throws {
        let state = AppState(events: CampusEvent.examples())
        let e = try XCTUnwrap(state.events.first)
        XCTAssertFalse(state.profile.studentNumber.isEmpty)
        XCTAssertFalse(SpaceRules.canAccess(e, state: state))
        XCTAssertFalse(SpaceRules.canRegister(e, state: state))
    }
    func testPendingAndRejectedCannotEnterSchool() throws {
        for status in [VerificationStatus.pending, .rejected] {
            var state = verifiedState(); state.settings.memberships[0].status = status
            XCTAssertFalse(SpaceRules.inCurrentSpace(state.events[0], state: state))
            XCTAssertThrowsError(try EventRules.register(event: state.events[0], state: &state))
        }
    }
    func testSchoolsAndSpacesAreIndependentlyIsolated() throws {
        var state = verifiedState()
        let campus = state.events[0]
        let other = try XCTUnwrap(state.events.first { $0.schoolID == "hnu" && $0.space == .campus })
        let city = try XCTUnwrap(state.events.first { $0.space == .city })
        XCTAssertTrue(SpaceRules.inCurrentSpace(campus, state: state))
        XCTAssertFalse(SpaceRules.canAccess(other, state: state))
        XCTAssertFalse(SpaceRules.inCurrentSpace(city, state: state))
        state.settings.activeSpace = .city
        XCTAssertTrue(SpaceRules.inCurrentSpace(city, state: state))
        XCTAssertFalse(SpaceRules.inCurrentSpace(campus, state: state))
        state.settings.activeSchoolID = "hnu"
        state.settings.activeSpace = .campus
        XCTAssertFalse(SpaceRules.inCurrentSpace(other, state: state))
    }
    func testCrossSchoolRegistrationDoesNotGrantHostSchoolMembership() throws {
        var state = verifiedState(); state.settings.activeSpace = .city
        let e = try XCTUnwrap(state.events.first { $0.space == .city && $0.audienceSchoolIDs == ["csust", "hnu"] })
        try EventRules.register(event: e, state: &state)
        XCTAssertEqual(state.registrations.first?.schoolID, "csust")
        XCTAssertEqual(SpaceRules.verifiedSchools(state), ["csust"])
        let hostCampus = try XCTUnwrap(state.events.first { $0.space == .campus && $0.schoolID == "hnu" })
        XCTAssertFalse(SpaceRules.canAccess(hostCampus, state: state))
    }
    func testCityAudienceRejectsUnverifiedAndExcludedSchools() throws {
        var state = verifiedState()
        let restricted = try XCTUnwrap(state.events.first { $0.audienceSchoolIDs == ["hnu", "csu"] })
        XCTAssertTrue(SpaceRules.canAccess(restricted, state: state))
        XCTAssertFalse(SpaceRules.canRegister(restricted, state: state))
        XCTAssertThrowsError(try EventRules.register(event: restricted, state: &state))
        state.settings.memberships = []
        let open = try XCTUnwrap(state.events.first { $0.space == .city && $0.audienceSchoolIDs.isEmpty })
        XCTAssertFalse(SpaceRules.canRegister(open, state: state))
    }
    func testDiscussionRequiresAdmissionAndCorrectSpace() throws {
        var state = verifiedState(); let e = state.events[0]
        XCTAssertFalse(SpaceRules.canDiscuss(e, state: state))
        state.registrations = [Registration(eventID: e.id, studentID: state.profile.id, status: .pending)]
        XCTAssertFalse(SpaceRules.canDiscuss(e, state: state))
        state.registrations[0].status = .confirmed
        XCTAssertTrue(SpaceRules.canDiscuss(e, state: state))
        state.settings.activeSpace = .city
        XCTAssertFalse(SpaceRules.canDiscuss(e, state: state))
        state.settings.activeSpace = .campus; state.settings.memberships = []
        XCTAssertFalse(SpaceRules.canDiscuss(e, state: state))
    }
    func testRecommendationsRequireInterestEligibilityAndSeparateOptIn() throws {
        var state = verifiedState()
        let city = try XCTUnwrap(state.events.first { $0.space == .city && $0.audienceSchoolIDs.isEmpty })
        XCTAssertFalse(SpaceRules.shouldRecommend(city, state: state))
        state.settings.cityRecommendations = true
        XCTAssertTrue(SpaceRules.shouldRecommend(city, state: state))
        state.settings.interests = [.art]
        XCTAssertFalse(SpaceRules.shouldRecommend(city, state: state))
        let restricted = try XCTUnwrap(state.events.first { $0.audienceSchoolIDs == ["hnu", "csu"] })
        XCTAssertFalse(SpaceRules.shouldRecommend(restricted, state: state))
    }
    func testCityCheckInDoesNotAwardCampusPoints() throws {
        var state = verifiedState(); state.settings.activeSpace = .city
        var event = try XCTUnwrap(state.events.first { $0.space == .city && $0.schoolID == "csust" })
        let now = Date(); event.start = now.addingTimeInterval(600); event.end = now.addingTimeInterval(3600); event.deadline = now.addingTimeInterval(300); event.hostID = state.profile.id
        event.creditHundredths = 100; event.creditMode = .automatic
        XCTAssertThrowsError(try EventRules.validate(event))
        state.events = [event]
        try EventRules.register(event: event, state: &state)
        try EventRules.checkIn(code: "huodongjun:local-ticket:\(state.registrations[0].ticketCode)", eventID: event.id, state: &state)
        XCTAssertEqual(state.registrations[0].status, .checkedIn)
        XCTAssertEqual(state.registrations[0].creditHundredths, 0)
        XCTAssertFalse(state.registrations[0].creditApproved)
    }
    @MainActor func testLegacyMigrationPreservesRecordsAndRequiresVerification() throws {
        var old = verifiedState()
        old.events = CampusEvent.examples(); old.version = 1
        old.registrations = [Registration(eventID: old.events[0].id, studentID: old.profile.id, status: .confirmed)]
        old.favorites.insert(old.events[0].id)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        object.removeValue(forKey: "spaceSettings")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        let store = AppStore(fileURL: url)
        XCTAssertEqual(store.state.registrations, old.registrations)
        XCTAssertEqual(store.state.favorites, old.favorites)
        XCTAssertEqual(store.profile.id, old.profile.id)
        XCTAssertFalse(store.schoolVerified)
        XCTAssertFalse(store.state.settings.setupCompleted)
        XCTAssertEqual(store.state.events.count, old.events.count + CampusEvent.expandedExamples().count)
        XCTAssertTrue(store.verifyDemo(schoolID: "csust", number: "DEMO123", college: "学院", status: .demoVerified))
        let reloaded = AppStore(fileURL: url)
        XCTAssertEqual(reloaded.state.events.count, store.state.events.count)
        XCTAssertTrue(reloaded.schoolVerified)
        XCTAssertNotNil(reloaded.registration(old.events[0].id))
    }
    @MainActor func testNoticeReadAndDiscussionDoNotCrossSpaces() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        let data = verifiedState()
        XCTAssertTrue(store.update { $0 = data })
        let campus = data.events[0]
        let city = try XCTUnwrap(data.events.first { $0.space == .city })
        XCTAssertTrue(store.update { $0.notices = [ActivityNotice(title: "校内", body: "", eventID: campus.id), ActivityNotice(title: "城市", body: "", eventID: city.id)] })
        XCTAssertEqual(store.unread, 1)
        store.markCurrentNoticesRead()
        store.switchSpace(.city)
        XCTAssertEqual(store.unread, 1)
        XCTAssertNil(store.event(campus.id))
        XCTAssertFalse(store.postMessage("越界", event: campus))
    }
    @MainActor func testPublishedScopeAndAudienceCannotBeExpandedByEdit() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        XCTAssertTrue(store.update { $0 = verifiedState() })
        var draft = store.events[0]; draft.id = UUID(); draft.hostID = store.profile.id
        XCTAssertTrue(store.publish(draft))
        draft.access = EventAccess(space: .city); draft.creditHundredths = 0
        XCTAssertFalse(store.publish(draft))
        XCTAssertEqual(store.event(draft.id)?.space, .campus)
    }
    @MainActor func testApprovalCannotUseAnotherEventsRegistrationID() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        var state = verifiedState()
        state.events[0].hostID = state.profile.id
        let other = Registration(eventID: state.events[1].id, studentID: state.profile.id, status: .pending)
        state.registrations = [other]
        XCTAssertTrue(store.update { $0 = state })
        var forged = other; forged.eventID = state.events[0].id
        store.approve(forged, event: state.events[0])
        XCTAssertEqual(store.state.registrations[0].status, .pending)
        XCTAssertNotNil(store.error)
    }
    @MainActor func testPreferenceRankingAndDigestDeduplication() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        XCTAssertTrue(store.update { $0 = verifiedState(); $0.settings.interests = [.music] })
        XCTAssertEqual(store.ranked(store.events).first?.cover, "music")
        XCTAssertEqual(store.previewRecommendations(), 1)
        XCTAssertEqual(store.previewRecommendations(), 0)
        XCTAssertEqual(store.notices.count, 1)
        XCTAssertTrue(store.update { $0.settings.interests = [.sport] })
        XCTAssertEqual(store.ranked(store.events).first?.category, .sport)
    }
}
