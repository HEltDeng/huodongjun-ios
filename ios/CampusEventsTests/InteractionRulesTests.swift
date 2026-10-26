import XCTest
@testable import CampusEvents

final class InteractionRulesTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func draft() -> CampusEvent {
        CampusEvent(title: "活动", summary: "", description: "", category: .study, location: "实验楼", start: now.addingTimeInterval(600), end: now.addingTimeInterval(3600), deadline: now.addingTimeInterval(300), host: "主办方", cover: "tech", capacity: 10)
    }
    func testFieldErrorsRemainUntilEachFieldIsCorrected() {
        var event = draft(); event.title = " "; event.location = ""; event.end = event.start
        let first = FormValidation.event(event, now: now)
        XCTAssertNotNil(first[.title]); XCTAssertNotNil(first[.location]); XCTAssertNotNil(first[.end])
        event.title = "新活动"
        let corrected = FormValidation.event(event, now: now)
        XCTAssertNil(corrected[.title]); XCTAssertNotNil(corrected[.location]); XCTAssertNotNil(corrected[.end])
        event.location = "活动中心"; event.end = event.start.addingTimeInterval(100)
        XCTAssertTrue(FormValidation.event(event, now: now).isEmpty)
    }
    func testTimeAudienceCapacityAndGroupErrorsStayIndependent() {
        var event = draft(); event.deadline = event.start.addingTimeInterval(1); event.capacity = 0; event.group.link = "http://example.com/group"
        let errors = FormValidation.event(event, needsAudience: true, now: now)
        XCTAssertNotNil(errors[.deadline]); XCTAssertNotNil(errors[.capacity]); XCTAssertNotNil(errors[.groupLink]); XCTAssertNotNil(errors[.audience])
        event.deadline = now.addingTimeInterval(100); event.capacity = 10; event.group.link = "https://example.com/group"; event.access = EventAccess(space: .city, audienceSchoolIDs: ["csust"])
        XCTAssertTrue(FormValidation.event(event, needsAudience: true, now: now).isEmpty)
    }
    func testPointsRejectExtraPrecisionAndInvalidNumbers() {
        XCTAssertEqual(FormValidation.points("0"), 0); XCTAssertEqual(FormValidation.points("0.01"), 1)
        XCTAssertEqual(FormValidation.points("99.99"), 9999); XCTAssertEqual(FormValidation.points("100"), 10000)
        for value in ["", "-1", "100.01", "0.001", "NaN", "1e2", "1,2"] { XCTAssertNil(FormValidation.points(value), value) }
    }
    @MainActor func withStore(_ run: (AppStore, URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "interaction-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AppStore(fileURL: url)
        XCTAssertTrue(store.verifyDemo(schoolID: "csust", number: "DEMO123", college: "测试", status: .demoVerified))
        try run(store, url)
    }
    @MainActor func testFavoriteUndoPersistsWithoutOverwritingOtherEdits() throws {
        try withStore { store, url in
            let event = try XCTUnwrap(store.events.first)
            store.favorite(event.id); let undo = try XCTUnwrap(store.snack?.undo)
            XCTAssertTrue(store.update { $0.profile.bio = "之后编辑的简介"; $0.settings.interests = [.music] })
            undo()
            let reloaded = AppStore(fileURL: url)
            XCTAssertFalse(reloaded.state.favorites.contains(event.id))
            XCTAssertEqual(reloaded.profile.bio, "之后编辑的简介"); XCTAssertEqual(reloaded.state.settings.interests, [.music])
        }
    }
    @MainActor func testRemovingFavoriteUndoRestoresIt() throws {
        try withStore { store, _ in
            let event = try XCTUnwrap(store.events.first)
            XCTAssertTrue(store.update { $0.favorites.insert(event.id) })
            store.favorite(event.id); XCTAssertFalse(store.state.favorites.contains(event.id))
            try XCTUnwrap(store.snack?.undo)()
            XCTAssertTrue(store.state.favorites.contains(event.id))
        }
    }
    @MainActor func testFollowUndoDoesNotLoseAnotherFollow() throws {
        try withStore { store, _ in
            store.follow("测试组织"); let undo = try XCTUnwrap(store.snack?.undo)
            store.follow("另一个组织"); undo()
            XCTAssertFalse(store.state.followedHosts.contains("测试组织")); XCTAssertTrue(store.state.followedHosts.contains("另一个组织"))
        }
    }
    @MainActor func testOldSnackExpiryCannotDismissNewNotice() throws {
        try withStore { store, _ in
            store.notify("第一条"); let id = try XCTUnwrap(store.snack?.id)
            store.notify("第二条"); store.dismissSnack(id)
            XCTAssertEqual(store.snack?.message, "第二条")
        }
    }
    @MainActor func testReadAllUndoIsScopedAndPreservesNewMessages() throws {
        try withStore { store, _ in
            let campus = try XCTUnwrap(store.events.first)
            let city = try XCTUnwrap(store.state.events.first { $0.space == .city })
            let first = ActivityNotice(title: "校内", body: "", eventID: campus.id)
            let second = ActivityNotice(title: "校外", body: "", eventID: city.id)
            XCTAssertTrue(store.update { $0.notices = [first, second] })
            store.markCurrentNoticesRead(); let undo = try XCTUnwrap(store.snack?.undo)
            let latest = ActivityNotice(title: "新消息", body: "", eventID: campus.id)
            XCTAssertTrue(store.update { $0.notices.append(latest) })
            undo()
            XCTAssertEqual(store.state.notices.count, 3)
            XCTAssertTrue(store.state.notices.allSatisfy { !$0.read })
        }
    }
    func testTourFlagIsBackwardCompatible() throws {
        let settings = SpaceSettings()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        json.removeValue(forKey: "interactionTourSeen")
        let restored = try JSONDecoder().decode(SpaceSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.interactionTourSeen)
    }
}
