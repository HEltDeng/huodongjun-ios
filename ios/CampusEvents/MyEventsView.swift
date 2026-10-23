import SwiftUI

struct MyEventsView: View {
    @Environment(AppStore.self) private var store
    @State private var filter = "即将参加"
    @State private var selected: CampusEvent?
    @State private var create = false
    var items: [CampusEvent] {
        store.scopedEvents.filter { event in
            switch filter {
            case "我主办的": return event.hostID == store.profile.id
            case "收藏": return store.state.favorites.contains(event.id)
            case "已结束": return store.registration(event.id) != nil && event.end <= Date()
            default: return store.registration(event.id) != nil && event.end > Date()
            }
        }.sorted { $0.start < $1.start }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SpaceSwitcher()
                    HStack { Text(store.space.title + "活动").font(.largeTitle.bold()); Spacer(); Button { create = true } label: { Image(systemName: "plus").font(.title3).frame(width: 42, height: 42).background(.white, in: Circle()) }.accessibilityLabel("创建活动") }
                    Picker("活动列表", selection: $filter) { ForEach(["即将参加", "已结束", "我主办的", "收藏"], id: \.self) { Text($0) } }.pickerStyle(.segmented).accessibilityIdentifier("myEvents.filter")
                    if store.space == .campus && !store.schoolVerified { CampusAccessPrompt() }
                    else if items.isEmpty {
                        EmptyState(symbol: filter == "收藏" ? "bookmark" : "calendar", title: filter == "我主办的" ? "把你的想法变成一场活动" : "这里还没有活动", subtitle: filter == "我主办的" ? "发起一次相聚，邀请同学一起参加。" : "在发现页找到喜欢的活动，加入你的校园日程。")
                        if filter == "我主办的" { Button { create = true } label: { Text("创建第一场活动").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()) }
                    }
                    ForEach(items) { event in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) { Circle().fill(Color.accentGreen.opacity(0.4)).frame(width: 8, height: 8); Text(event.start.formatted(.dateTime.month().day().weekday(.wide))).font(.subheadline.weight(.medium)); Spacer(); if event.cancelled { Tag(text: "活动已取消", color: .red) } }
                            Button { selected = event } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    EventRow(event: event)
                                    if let reg = store.registration(event.id) { HStack { Tag(text: reg.status.rawValue); Spacer(); if [.confirmed, .checkedIn].contains(reg.status) { Label("入场凭证", systemImage: "qrcode").font(.caption).foregroundStyle(.secondary) } } }
                                }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(SoftPressStyle())
                        }
                    }
                }.padding(22)
            }.background(Color.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(item: $selected) { EventDetailView(eventID: $0.id) }
                .sheet(isPresented: $create) { EventEditorView() }
                .onChange(of: store.contextID) { _, _ in selected = nil; create = false }
        }
    }
}

struct NoticesView: View {
    @Environment(AppStore.self) private var store
    @State private var selected: CampusEvent?
    @State private var selection = "通知"
    @State private var path = NavigationPath()
    var conversations: [CampusEvent] { store.conversations }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SpaceSwitcher()
                    HStack { Text(store.space.title + "消息").font(.largeTitle.bold()); Spacer(); if store.unread > 0 { Button("全部已读") { store.markCurrentNoticesRead() }.font(.caption).accessibilityIdentifier("notices.readAll") } }
                    Picker("消息类型", selection: $selection) { Text("通知").tag("通知"); Text("活动讨论").tag("讨论") }.pickerStyle(.segmented)
                    if selection == "通知" {
                        if store.notices.isEmpty { EmptyState(symbol: "bell", title: "不错过每一次相聚", subtitle: "报名结果和活动更新会显示在这里。") }
                        ForEach(store.notices) { notice in
                            Button {
                                store.update { state in if let i = state.notices.firstIndex(where: { $0.id == notice.id }) { state.notices[i].read = true } }
                                selected = notice.eventID.flatMap(store.event)
                            } label: {
                                HStack(alignment: .top, spacing: 13) {
                                    Image(systemName: "calendar.badge.checkmark").font(.title3).foregroundStyle(Color.accentGreen).frame(width: 42, height: 42).background(Color.accentGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                                    VStack(alignment: .leading, spacing: 7) { HStack { Text(notice.title).font(.subheadline.bold()); Spacer(); if !notice.read { Circle().fill(Color.accentGreen).frame(width: 7, height: 7) } }; Text(notice.body).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading); Text(notice.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.tertiary) }
                                }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(SoftPressStyle())
                        }
                    } else {
                        if conversations.isEmpty { EmptyState(symbol: "bubble.left.and.bubble.right", title: "从一场活动开始聊天", subtitle: "报名后，就能在这里找到活动讨论。") }
                        ForEach(conversations) { event in NavigationLink { DiscussionView(eventID: event.id) } label: { HStack(spacing: 13) { EventCover(event: event).frame(width: 52, height: 52).clipped().clipShape(RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 7) { Text(event.title).font(.subheadline.bold()); Text(store.state.messages.last(where: { $0.eventID == event.id })?.body ?? "查看活动讨论").font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 17)) }.buttonStyle(SoftPressStyle()) }
                    }
                }.padding(22)
            }.background(Color.paper).toolbar(.hidden, for: .navigationBar).sheet(item: $selected) { EventDetailView(eventID: $0.id) }
                .onChange(of: store.contextID) { _, _ in selected = nil; path = NavigationPath() }
        }
    }
}

struct DiscussionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppStore.self) private var store
    var eventID: UUID
    @State private var text = ""
    @State private var error: String?
    var body: some View {
        Group {
        if let event = store.event(eventID), SpaceRules.canDiscuss(event, state: store.state) {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        let messages = store.state.messages.filter { $0.eventID == eventID }
                        if messages.isEmpty { EmptyState(symbol: "bubble.left.and.bubble.right", title: "聊聊这场活动", subtitle: "分享期待，或留下你的问题。") }
                        ForEach(messages) { message in
                            HStack(alignment: .top, spacing: 10) { HostAvatar(name: message.author); VStack(alignment: .leading, spacing: 7) { Text(message.author).font(.caption).foregroundStyle(.secondary); Text(message.body).font(.subheadline).padding(13).background(.white, in: RoundedRectangle(cornerRadius: 14)); Text(message.date.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.tertiary) }; Spacer(minLength: 15) }.id(message.id)
                        }
                    }.padding(20)
                }.onChange(of: store.state.messages.count) { _, _ in if let last = store.state.messages.last { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
            HStack(spacing: 12) {
                TextField("聊聊这场活动…", text: $text, axis: .vertical).lineLimit(1...5).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16))
                Button { if let event = store.event(eventID) { if store.postMessage(text, event: event) { text = "" } else { error = store.error; store.error = nil } } } label: { Image(systemName: "arrow.up").font(.headline).foregroundStyle(.white).frame(width: 42, height: 42).background(Color.ink, in: Circle()) }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("发送消息")
            }.padding(16).background(.regularMaterial)
        }
        } else { ContentUnavailableView("暂时无法进入讨论", systemImage: "lock", description: Text("请验证学校身份并完成活动报名。")) }
        }.background(Color.paper).navigationTitle(store.event(eventID)?.title ?? "活动讨论").navigationBarTitleDisplayMode(.inline)
            .alert("无法发送", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("知道了") { error = nil } } message: { Text(error ?? "") }
    }
}
