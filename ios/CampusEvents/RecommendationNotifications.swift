import Foundation
import UserNotifications

@MainActor enum RecommendationNotifications {
    private static var task: Task<Void, Never>?
    static func schedule(state: AppState) {
        task?.cancel()
        task = Task {
            let center = UNUserNotificationCenter.current()
            let authorization = await center.notificationSettings()
            guard !Task.isCancelled else { return }
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled else { return }
            let ids = pending.map(\.identifier).filter { $0.hasPrefix("interest-digest-") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            guard [.authorized, .provisional].contains(authorization.authorizationStatus) else { return }
            let now = Date()
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
            var components = DateComponents(hour: 19, minute: 0)
            if state.settings.frequency == .weekly { components.weekday = 1 }
            guard let next = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return }
            for space in ActivitySpace.allCases {
                let items = state.events.filter { $0.space == space && SpaceRules.shouldRecommend($0, state: state, now: next) }
                    .sorted { SpaceRules.recommendationScore($0, state: state) > SpaceRules.recommendationScore($1, state: state) }.prefix(3)
                guard !items.isEmpty, !Task.isCancelled else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(space.title) · 你的兴趣精选"
                content.body = items.map(\.title).joined(separator: "、")
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, next.timeIntervalSinceNow), repeats: false)
                let identifier = "interest-digest-\(space.rawValue)-\(UUID().uuidString)"
                try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                // A cancelled update must never leave a stale digest behind.
                if Task.isCancelled { center.removePendingNotificationRequests(withIdentifiers: [identifier]) }
            }
        }
    }
}
