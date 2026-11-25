import Foundation
import Observation

private final class CompetitionRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, CompetitionSource.isSourceURL(url),
              let original = task.originalRequest?.url,
              !CompetitionSource.isChinaFeed(original) || original.path == url.path else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

struct CompetitionClient {
    var session: URLSession = .shared
    func html(at url: URL) async throws -> String {
        guard CompetitionSource.isSourceURL(url) else { throw CompetitionLoadError.unavailable }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let limit = 8_000_000
        let (bytes, response) = try await session.bytes(for: request, delegate: CompetitionRedirectPolicy())
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              let finalURL = response.url, CompetitionSource.isSourceURL(finalURL),
              !CompetitionSource.isChinaFeed(url) || finalURL.path == url.path,
              response.expectedContentLength < Int64(limit) else { throw CompetitionLoadError.unavailable }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit - 1 else { throw CompetitionLoadError.unavailable }
            data.append(byte)
        }
        guard let html = String(data: data, encoding: .utf8) else { throw CompetitionLoadError.unavailable }
        return html
    }
    func feed(at url: URL) async throws -> CompetitionFeed {
        guard CompetitionSource.isChinaFeed(url) else { throw CompetitionLoadError.unavailable }
        return try CompeteHubParser.feed(html: await html(at: url), url: url)
    }
    func detail(_ item: OfficialCompetition) async throws -> OfficialCompetition { try CompeteHubParser.detail(html: await html(at: item.sourceURL), base: item) }
}

@Observable @MainActor
final class CompetitionStore {
    private(set) var items: [OfficialCompetition] = []
    private(set) var regions: [CompetitionRegion] = []
    private(set) var updatedAt: Date?
    private(set) var isLoading = false
    private(set) var isHydrating = false
    private(set) var isCached = false
    private(set) var error: String?
    private(set) var nextURL: URL?
    private(set) var detailFailures = Set<String>()
    private(set) var favorites = Set<String>()
    private var selectedURL: URL?
    private var generation = UUID()
    private var cache: [String: CompetitionFeed] = [:]
    private var details: [String: OfficialCompetition] = [:]
    private let client: CompetitionClient
    private let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "OfficialCompetitions"), client: CompetitionClient = CompetitionClient()) {
        self.directory = directory; self.client = client
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: directory.appending(path: "feeds.json")), let value = try? JSONDecoder().decode([String: CompetitionFeed].self, from: data) {
            cache = value.filter { URL(string: $0.key).map(CompetitionSource.isChinaFeed) == true }
        }
        if let data = try? Data(contentsOf: directory.appending(path: "details.json")), let value = try? JSONDecoder().decode([String: OfficialCompetition].self, from: data) { details = value }
        if let data = try? Data(contentsOf: directory.appending(path: "favorites.json")), let value = try? JSONDecoder().decode(Set<String>.self, from: data) { favorites = value }
        regions = cache[CompetitionSource.feedURL().absoluteString]?.regions.filter { $0.key == "China" } ?? []
    }
    func toggleFavorite(_ id: String) {
        var next = favorites
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        do {
            try JSONEncoder().encode(next).write(to: directory.appending(path: "favorites.json"), options: .atomic)
            favorites = next
        } catch { self.error = "收藏未能保存，请重试。" }
    }
    func load(city: String = "All", force: Bool = false) async {
        let url = CompetitionSource.feedURL(city: city)
        if selectedURL == url, !force, updatedAt != nil { return }
        let token = UUID(); generation = token; selectedURL = url
        isLoading = true; isHydrating = false; error = nil; detailFailures = []
        if let saved = cache[url.absoluteString] { apply(saved); isCached = true }
        else { items = []; updatedAt = nil; nextURL = nil; isCached = false }
        do {
            let feed = try await client.feed(at: url)
            try Task.checkCancellation()
            guard generation == token else { return }
            cache[url.absoluteString] = feed; persistCache()
            apply(feed); isCached = false; isLoading = false
            await hydrate(token: token, force: force)
        } catch {
            guard generation == token else { return }
            isLoading = false
            if !Task.isCancelled { self.error = "刷新失败。" + (items.isEmpty ? "请重试或查看来源。" : "正在显示上次保存的赛事。") }
        }
    }
    func loadMore() async {
        guard let url = nextURL, CompetitionSource.isChinaFeed(url), !isLoading, !isHydrating else { return }
        let token = generation
        isLoading = true; error = nil
        do {
            let feed = try await client.feed(at: url)
            try Task.checkCancellation()
            guard token == generation else { return }
            let ids = Set(items.map(\.id))
            items.append(contentsOf: feed.items.filter { !ids.contains($0.id) }.map(mergingDetail))
            nextURL = feed.nextURL; isLoading = false
            if let selectedURL {
                cache[selectedURL.absoluteString] = CompetitionFeed(items: items, regions: regions, nextURL: nextURL, fetchedAt: feed.fetchedAt)
                persistCache()
            }
            await hydrate(token: token, force: false)
        } catch {
            guard token == generation else { return }
            isLoading = false
            if !Task.isCancelled { self.error = "更多赛事加载失败，请重试。" }
        }
    }
    func refreshDetail(_ item: OfficialCompetition) async {
        let token = generation
        do {
            let fresh = try await client.detail(item)
            try Task.checkCancellation()
            details[item.id] = fresh
            if token == generation { replace(fresh); detailFailures.remove(item.id) }
            persistDetails()
        } catch {
            if token == generation, !Task.isCancelled { detailFailures.insert(item.id) }
        }
    }
    func item(_ id: String) -> OfficialCompetition? { items.first { $0.id == id } ?? details[id] }
    private func apply(_ feed: CompetitionFeed) {
        items = feed.items.map(mergingDetail)
        nextURL = feed.nextURL.flatMap { CompetitionSource.isChinaFeed($0) && $0.path == selectedURL?.path ? $0 : nil }
        updatedAt = feed.fetchedAt
        let chineseRegions = feed.regions.filter { $0.key == "China" }
        if !chineseRegions.isEmpty { regions = chineseRegions }
    }
    private func mergingDetail(_ item: OfficialCompetition) -> OfficialCompetition {
        guard let saved = details[item.id] else { return item }
        var result = saved
        result.title = item.title; result.category = item.category; result.platform = item.platform; result.tags = item.tags
        return result
    }
    private func replace(_ item: OfficialCompetition) {
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item }
    }
    private func hydrate(token: UUID, force: Bool) async {
        isHydrating = true
        let pending = items.filter { force || $0.fetchedAt.map { Date().timeIntervalSince($0) > 6 * 3600 } ?? true }
        // Bounded concurrency, with cancellation and generation checks when switching regions.
        for start in stride(from: 0, to: pending.count, by: 4) {
            guard generation == token, !Task.isCancelled else { break }
            let batch = Array(pending[start..<min(start + 4, pending.count)])
            await withTaskGroup(of: (String, OfficialCompetition?).self) { group in
                for item in batch { group.addTask { [client] in (item.id, try? await client.detail(item)) } }
                for await (id, item) in group {
                    guard generation == token, !Task.isCancelled else { continue }
                    if let item { details[id] = item; replace(item); detailFailures.remove(id) }
                    else { detailFailures.insert(id) }
                }
            }
        }
        if generation == token { isHydrating = false; persistDetails() }
    }
    private func persistCache() {
        try? JSONEncoder().encode(cache).write(to: directory.appending(path: "feeds.json"), options: .atomic)
    }
    private func persistDetails() {
        try? JSONEncoder().encode(details).write(to: directory.appending(path: "details.json"), options: .atomic)
    }
}
