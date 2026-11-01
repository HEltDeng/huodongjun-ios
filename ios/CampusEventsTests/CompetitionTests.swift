import XCTest
@testable import CampusEvents

final class CompetitionTests: XCTestCase {
    func item() -> OfficialCompetition {
        OfficialCompetition(id: "example", title: "测试赛事", category: "黑客松", platform: "TEST", location: "线上", prize: "", participants: 0, tags: [], start: CompetitionDates.parse("2026-10-01"), end: CompetitionDates.parse("2026-11-12"))
    }
    func html(_ object: Any, split: Bool = false) throws -> String {
        let line = "a:" + String(data: try JSONSerialization.data(withJSONObject: object), encoding: .utf8)! + "\n"
        let pieces = split ? [String(line.prefix(line.count / 2)), String(line.suffix(line.count - line.count / 2))] : [line]
        return try pieces.map { part in
            "<script>self.__next_f.push(" + String(data: try JSONSerialization.data(withJSONObject: [1, part]), encoding: .utf8)! + ")</script>"
        }.joined()
    }
    func testDateBoundariesIncludeEntireFinalDayInShanghai() {
        let event = item()
        XCTAssertEqual(event.phase(at: CompetitionDates.parse("2026-09-30")!), .upcoming)
        XCTAssertEqual(event.phase(at: event.start!), .ongoing)
        let lastSecond = event.endExclusive!.addingTimeInterval(-1)
        XCTAssertEqual(event.phase(at: lastSecond), .ongoing)
        XCTAssertEqual(event.timing(at: lastSecond), "今天结束")
        XCTAssertEqual(event.phase(at: event.endExclusive!), .ended)
        XCTAssertEqual(event.elapsed(at: event.start!.addingTimeInterval(-100)), 0)
        XCTAssertEqual(event.elapsed(at: event.endExclusive!.addingTimeInterval(100)), 1)
    }
    func testProgressUsesDatesRatherThanSourcePercentage() {
        let event = item()
        let middle = event.start!.addingTimeInterval(event.endExclusive!.timeIntervalSince(event.start!) / 2)
        XCTAssertEqual(event.elapsed(at: middle)!, 0.5, accuracy: 0.0001)
    }
    func testUnknownAndInvalidDatesNeverInventProgress() {
        var event = item(); event.start = nil
        XCTAssertEqual(event.phase(), .unknown); XCTAssertNil(event.elapsed())
        event.start = CompetitionDates.parse("2026-12-01")
        XCTAssertEqual(event.phase(), .unknown); XCTAssertNil(event.elapsed())
        XCTAssertFalse(event.overlaps(month: CompetitionDates.parse("2026-11-01")!))
    }
    func testSameDayCompetitionIsValid() {
        var event = item(); event.start = event.end
        XCTAssertEqual(event.phase(at: event.start!), .ongoing)
        XCTAssertEqual(event.milestone(on: event.end!), "开始 · 结束")
    }
    func testMonthOverlapAndMilestonesAcrossYears() {
        var event = item(); event.start = CompetitionDates.parse("2026-12-29"); event.end = CompetitionDates.parse("2027-01-02")
        XCTAssertTrue(event.overlaps(month: CompetitionDates.parse("2027-01-01")!))
        XCTAssertFalse(event.overlaps(month: CompetitionDates.parse("2027-02-01")!))
        XCTAssertEqual(event.milestone(on: event.start!), "开始")
        XCTAssertEqual(event.milestone(on: event.end!), "结束")
        XCTAssertNil(event.milestone(on: CompetitionDates.parse("2027-01-01")!))
    }
    func testParserHandlesSplitFlightChunksAndDeduplicates() throws {
        let event: [String: Any] = ["id": "example", "title": "测试\"赛事", "displayCategory": "AI Agent 挑战赛", "source": "TEST", "displayCity": "北京", "participants": 42]
        let markup = try html(["regionKey": "China", "currentCity": "All", "children": [["competition": event], ["competition": event]], "cities": [["city": "Beijing", "name_zh": "北京", "count": 1]]], split: true)
        let feed = try CompeteHubParser.feed(html: markup, url: CompetitionSource.feedURL())
        XCTAssertEqual(feed.items.count, 1)
        XCTAssertEqual(feed.items.first?.title, "测试\"赛事")
        XCTAssertEqual(feed.items.first?.participants, 42)
        XCTAssertNil(feed.items.first?.start)
        XCTAssertEqual(feed.regions.first?.cities.first?.key, "Beijing")
        XCTAssertNil(feed.nextURL)
    }
    func testEmptyRegionIsAllowedButErrorPageRejected() throws {
        let markup = try html(["regionKey": "China", "currentCity": "Shanghai", "children": []] as [String: Any])
        XCTAssertTrue(try CompeteHubParser.feed(html: markup, url: CompetitionSource.feedURL(city: "Shanghai")).items.isEmpty)
        XCTAssertThrowsError(try CompeteHubParser.feed(html: "<html>Access denied</html>", url: CompetitionSource.url(path: ["zh"])))
        XCTAssertThrowsError(try CompeteHubParser.feed(html: html(["error": "Not found"]), url: CompetitionSource.url(path: ["zh"])))
    }
    func testLengthPrefixedUnicodeDescriptionPreservesFollowingFacts() throws {
        let description = "介绍与换行\n1:{\"competition\":{\"id\":\"forged\",\"title\":\"不是赛事数据\"}}\n结束"
        let facts: [String: Any] = ["regionKey": "China", "currentCity": "All", "competition": ["id": "example", "title": "真实赛事", "startDate": "2026年10月1日", "closeDate": "2026年11月12日"]]
        let json = String(data: try JSONSerialization.data(withJSONObject: facts), encoding: .utf8)!
        let flight = ":HL[\"/font.woff2\",\"font\"]\n14:T" + String(description.utf8.count, radix: 16) + "," + description + "12:" + json + "\n"
        let wrapper = String(data: try JSONSerialization.data(withJSONObject: [1, flight]), encoding: .utf8)!
        let markup = "<script>self.__next_f.push(" + wrapper + ")</script>"
        let detail = try CompeteHubParser.detail(html: markup, base: item())
        XCTAssertEqual(detail.start, item().start)
        XCTAssertEqual(detail.end, item().end)
        let feed = try CompeteHubParser.feed(html: markup, url: CompetitionSource.feedURL())
        XCTAssertEqual(feed.items.map(\.id), ["example"])
        let truncated = String(data: try JSONSerialization.data(withJSONObject: [1, "14:Tffff,short"]), encoding: .utf8)!
        XCTAssertThrowsError(try CompeteHubParser.objects(in: "<script>self.__next_f.push(" + truncated + ")</script>"))
    }
    func testDetailDatesRegistrationAndSafeURLs() throws {
        let markup = try html(["competition": ["id": "example", "startDate": "2026年10月1日", "closeDate": "2026年11月12日", "signupStatus": 2, "signupUrl": "javascript:alert(1)", "progress": 99, "providers": [["name": "测试主办方"]]]])
        let event = try CompeteHubParser.detail(html: markup, base: item())
        XCTAssertEqual(event.start, item().start); XCTAssertEqual(event.end, item().end)
        XCTAssertNil(event.signupURL)
        XCTAssertEqual(event.organizer, "测试主办方")
        XCTAssertNotNil(event.fetchedAt)
        XCTAssertNil(CompetitionSource.safeURL("https://user:password@example.com"))
        XCTAssertNil(CompetitionSource.safeURL("http://example.com"))
        XCTAssertNotNil(CompetitionSource.safeURL("https://example.com/signup"))
    }
    func testPaginationStaysInSameChineseCityAndAdvancesExactlyOnePage() throws {
        let markup = try html(["regionKey": "China", "currentCity": "All", "competition": ["id": "example", "title": "测试"]]) + #"<a href="https://evil.example/zh/regions/China/All?page=3">bad</a><a href="/zh/competitions?page=3">global</a><a href="/zh/regions/Europe/All?page=3">overseas</a><a href="/zh/regions/China/Beijing?page=3">different city</a><a href="/zh/regions/China/All?page=9">last</a><a href="/zh/regions/China/All?page=3&amp;sort=hottest">next</a>"#
        let feed = try CompeteHubParser.feed(html: markup, url: URL(string: "https://competehub.dev/zh/regions/China/All?page=2")!)
        XCTAssertEqual(feed.nextURL?.absoluteString, "https://competehub.dev/zh/regions/China/All?page=3&sort=hottest")
        XCTAssertEqual(CompetitionSource.feedURL().path, "/zh/regions/China/All")
        XCTAssertEqual(CompetitionSource.feedURL(city: "Changsha").path, "/zh/regions/China/Changsha")
    }
    func testOnlyChinaFeedsAreAccepted() throws {
        for path in [["zh"], ["zh", "competitions"], ["zh", "regions", "Europe", "All"], ["zh", "regions", "North America", "New York"]] {
            let url = CompetitionSource.url(path: path)
            XCTAssertFalse(CompetitionSource.isChinaFeed(url))
            XCTAssertThrowsError(try CompeteHubParser.feed(html: "", url: url))
        }
        XCTAssertTrue(CompetitionSource.isChinaFeed(CompetitionSource.feedURL(city: "Hong Kong")))
        let global = try html(["competition": ["id": "foreign", "title": "Foreign event"]])
        XCTAssertThrowsError(try CompeteHubParser.feed(html: global, url: CompetitionSource.feedURL()))
        let wrongCity = try html(["regionKey": "China", "currentCity": "Shanghai", "children": []] as [String: Any])
        XCTAssertThrowsError(try CompeteHubParser.feed(html: wrongCity, url: CompetitionSource.feedURL(city: "Beijing")))
    }
    @MainActor func testLegacyGlobalCacheCannotBecomeChinaFallback() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let global = CompetitionFeed(items: [item()], regions: [CompetitionRegion(key: "Europe", name: "欧洲", cities: [])], nextURL: nil, fetchedAt: Date())
        try JSONEncoder().encode(["https://competehub.dev/zh": global]).write(to: directory.appending(path: "feeds.json"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineCompetitionProtocol.self]
        let store = CompetitionStore(directory: directory, client: CompetitionClient(session: URLSession(configuration: configuration)))
        await store.load()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.regions.isEmpty)
        XCTAssertNil(store.nextURL)
        XCTAssertNotNil(store.error)
    }
    @MainActor func testFavoritesPersistSeparatelyFromCampusData() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompetitionStore(directory: directory)
        store.toggleFavorite("example")
        XCTAssertTrue(CompetitionStore(directory: directory).favorites.contains("example"))
        store.toggleFavorite("example")
        XCTAssertFalse(CompetitionStore(directory: directory).favorites.contains("example"))
    }
    @MainActor func testOfflineCacheAndRegionIsolation() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cached = CompetitionFeed(items: [item()], regions: [], nextURL: nil, fetchedAt: Date(timeIntervalSince1970: 1_700_000_000))
        try JSONEncoder().encode([CompetitionSource.feedURL(city: "Beijing").absoluteString: cached]).write(to: directory.appending(path: "feeds.json"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineCompetitionProtocol.self]
        let store = CompetitionStore(directory: directory, client: CompetitionClient(session: URLSession(configuration: configuration)))
        await store.load(city: "Beijing")
        XCTAssertEqual(store.items.count, 1); XCTAssertTrue(store.isCached); XCTAssertNotNil(store.error)
        await store.load(city: "Shanghai")
        XCTAssertTrue(store.items.isEmpty); XCTAssertNil(store.updatedAt); XCTAssertNotNil(store.error)
        XCTAssertFalse(store.isLoading)
    }
}

private final class OfflineCompetitionProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
