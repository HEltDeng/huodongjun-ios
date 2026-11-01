import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var create = false
    @State private var search = ""
    @State private var schools = false
    @State private var interests = false
    @State private var spaces = false
    @State private var openSchoolAfterSpace = false
    @State private var recommended = true
    @State private var path = NavigationPath()
    @State private var searchVisible = false
    @State private var category: Category = .all
    @State private var campus: Campus = .all
    @State private var availableOnly = false
    @State private var filters = false
    @State private var selected: CampusEvent?
    var filtered: [CampusEvent] {
        let source = recommended && !SpaceRules.verifiedSchools(store.state).isEmpty ? store.ranked(store.events) : store.events
        return source.filter { event in
            (category == .all || category == event.category) && (store.space == .city || store.school.id != "csust" || campus == .all || campus == event.campus) &&
            (!availableOnly || (event.deadline > Date() && store.count(event) < event.capacity)) &&
            (search.isEmpty || "\(event.title)\(event.host)\(event.location)\(event.description)\(event.topics.map(\.title).joined())".localizedCaseInsensitiveContains(search))
        }
    }
    var featured: [CampusEvent] {
        var covers = Set<String>()
        let varied = filtered.filter { covers.insert($0.imageData == nil ? $0.cover : $0.id.uuidString).inserted }
        return Array((varied + filtered.filter { event in !varied.contains(where: { $0.id == event.id }) }).prefix(4))
    }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(store.space == .campus ? "发现校园" : "发现长沙").font(.system(size: 30, weight: .bold))
                            Button { spaces = true } label: { Label(store.space == .campus ? store.school.name : "长沙 · 高校开放活动", systemImage: "location.fill").font(.subheadline).foregroundStyle(.secondary) }.buttonStyle(SoftPressStyle())
                        }
                        Spacer()
                        Button { create = true } label: { Image(systemName: "plus").font(.system(size: 20, weight: .medium)).frame(width: 44, height: 44).background(.white, in: Circle()) }.buttonStyle(SoftPressStyle()).accessibilityLabel("发布活动").accessibilityIdentifier("nav.create")
                    }.padding(.horizontal, 22).padding(.top, 16)
                    SpaceSwitcher().padding(.horizontal, 22)
                    HStack(spacing: 17) {
                        selection("为你推荐", active: recommended) { recommended = true }
                        selection("全部活动", active: !recommended) { recommended = false }
                        Spacer()
                        if !search.isEmpty { Button { search = "" } label: { Label(search, systemImage: "xmark.circle.fill").font(.caption).lineLimit(1) }.buttonStyle(SoftPressStyle()).accessibilityLabel("清除搜索") }
                    }.padding(.horizontal, 22)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(Category.allCases) { item in
                                Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { category = item } } label: {
                                    Label(item.rawValue, systemImage: item.symbol).font(.system(size: 13, weight: .medium)).padding(.horizontal, 14).frame(minHeight: 44).foregroundStyle(category == item ? .white : Color.primary).background(category == item ? Color.ink : .white, in: Capsule())
                                }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("category.\(item.rawValue)")
                            }
                        }.padding(.horizontal, 22)
                    }
                    if store.space == .campus && !store.schoolVerified { CampusAccessPrompt() }
                    else if filtered.isEmpty { EmptyState(symbol: "magnifyingglass", title: "暂时没有找到活动", subtitle: "换个关键词，或试试其他分类。") }
                    else {
                        if category == .all && search.isEmpty {
                            HStack { Text(recommended ? "为你精选" : "本周精选").font(.title3.bold()); Spacer(); Text("一起，才有意思").font(.caption).foregroundStyle(.secondary) }.padding(.horizontal, 22)
                            SnapEventCarousel(events: featured) { selected = $0 }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text(search.isEmpty ? "活动日程" : "搜索结果").font(.title3.bold()); Spacer(); Text("\(filtered.count) 场").font(.caption).foregroundStyle(.secondary).contentTransition(.numericText()) }
                            ForEach(filtered) { event in Button { selected = event } label: { EventRow(event: event) }.buttonStyle(SoftPressStyle()); if event.id != filtered.last?.id { Divider().opacity(0.5) } }
                        }.padding(.horizontal, 22)
                        if category == .all && search.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("找到你的同好").font(.title3.bold())
                                ForEach(Array(Set(store.events.map(\.host))).sorted(), id: \.self) { host in
                                    NavigationLink { HostView(host: host) } label: {
                                        HStack(spacing: 12) { HostAvatar(name: host, size: 42); VStack(alignment: .leading, spacing: 5) { Text(host).font(.subheadline.weight(.semibold)); Text(store.space == .campus ? store.school.name : "长沙 · 活动主办方").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 19))
                                    }.buttonStyle(SoftPressStyle())
                                }
                            }.padding(.horizontal, 22)
                        }
                    }
                }.padding(.bottom, 22)
            }.background(Color.paper).toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 0) {
                        quick("空间", icon: "building.2") { spaces = true }
                        quick("搜索", icon: "magnifyingglass") { searchVisible = true }
                        quick("兴趣", icon: "sparkles") { interests = true }
                        quick("筛选", icon: "line.3.horizontal.decrease") { filters = true }
                    }.padding(.vertical, 3).background(.regularMaterial, in: Capsule()).padding(.horizontal, 28).padding(.bottom, 10)
                }
                .sheet(isPresented: $create) { EventEditorView().appSheet(.large, stops: [SheetSize.tall, .large]) }
                .sheet(item: $selected) { EventDetailView(eventID: $0.id).appSheet() }
                .sheet(isPresented: $schools) { SchoolPickerView().appSheet(SheetSize.half) }
                .sheet(isPresented: $interests) { InterestSelectionView().appSheet() }
                .sheet(isPresented: $spaces, onDismiss: { if openSchoolAfterSpace { openSchoolAfterSpace = false; schools = true } }) {
                    NavigationStack {
                        VStack(spacing: 22) {
                            SpaceSwitcher()
                            Button { openSchoolAfterSpace = true; spaces = false } label: { SchoolCard(school: store.school, status: store.state.settings.memberships.first { $0.schoolID == store.school.id }?.status) }.buttonStyle(SoftPressStyle())
                            Button("进入\(store.space.title)") { spaces = false }.buttonStyle(QuietButton())
                        }.padding(22).navigationTitle("选择活动空间").navigationBarTitleDisplayMode(.inline)
                    }.appSheet(SheetSize.half, stops: [SheetSize.peek, SheetSize.half, SheetSize.tall])
                }
                .sheet(isPresented: $searchVisible) { searchPanel.appSheet(SheetSize.half, stops: [SheetSize.half, SheetSize.tall, .large]) }
                .sheet(isPresented: $filters) { filterPanel.appSheet(SheetSize.half, stops: [SheetSize.peek, SheetSize.half, SheetSize.tall]) }
                .onChange(of: store.contextID) { _, _ in path = NavigationPath(); selected = nil; campus = .all; category = .all; search = ""; filters = false }
        }
    }
    func selection(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2), action) } label: {
            VStack(spacing: 8) { Text(title).font(.subheadline.weight(active ? .semibold : .regular)).foregroundStyle(active ? Color.ink : .secondary); Capsule().fill(active ? Color.accentGreen : .clear).frame(height: 3) }
        }.buttonStyle(SoftPressStyle()).fixedSize(horizontal: true, vertical: false)
    }
    func quick(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, minHeight: 40).contentShape(Rectangle()) }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("discover.\(title)")
    }
    var searchPanel: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("活动、地点或主办方", text: $search).submitLabel(.search).onSubmit { searchVisible = false }.accessibilityIdentifier("discover.searchField"); if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("清除关键词") } }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 17))
                Text("探索一个方向").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) { ForEach(Interest.allCases.prefix(6)) { topic in Button(topic.title) { search = topic.title; searchVisible = false }.buttonStyle(QuietButton()) } }
                Spacer(minLength: 0)
                Button { searchVisible = false } label: { Text("查看搜索结果").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton())
                Button("取消") { searchVisible = false }.buttonStyle(QuietButton())
            }.padding(22).navigationTitle("搜索活动").navigationBarTitleDisplayMode(.inline)
        }
    }
    var filterPanel: some View {
        NavigationStack {
            Form {
                if store.space == .campus && store.school.id == "csust" { Section("校区") { Picker("选择校区", selection: $campus) { ForEach(Campus.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline).labelsHidden() } }
                Section { Toggle("仅看仍有名额的活动", isOn: $availableOnly) }
            }.scrollContentBackground(.hidden).navigationTitle("筛选活动").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) { HStack(spacing: 12) { Button("重置") { campus = .all; availableOnly = false; category = .all }.buttonStyle(QuietButton()); Button { filters = false } label: { Text("查看 \(filtered.count) 场活动").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()) }.padding(20).background(.regularMaterial) }
        }
    }
}
struct SnapEventCarousel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let events: [CampusEvent]
    var select: (CampusEvent) -> Void
    @State private var focused: UUID?
    var body: some View {
        let motionDisabled = reduceMotion
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 15) {
                    ForEach(events) { event in
                        Button { select(event) } label: {
                            VStack(alignment: .leading, spacing: 11) {
                                Color.clear.aspectRatio(1.2, contentMode: .fit).overlay { EventCover(event: event) }.clipped().clipShape(RoundedRectangle(cornerRadius: 25))
                                Text(event.start.formatted(.dateTime.month().day().weekday().hour().minute())).font(.caption.weight(.medium)).foregroundStyle(Color.accentGreen)
                                Text(event.title).font(.system(size: 18, weight: .bold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                                HStack(spacing: 6) { HostAvatar(name: event.host, size: 20); Text(event.host).font(.caption).foregroundStyle(.secondary).lineLimit(1); Spacer(); if event.space == .campus && event.creditHundredths > 0 { Tag(text: "+\(event.creditText) 综测") } }
                            }.containerRelativeFrame(.horizontal, count: 5, span: 4, spacing: 15)
                        }.buttonStyle(SoftPressStyle()).id(event.id)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in content.scaleEffect(motionDisabled ? 1 : phase.isIdentity ? 1 : 0.96).opacity(phase.isIdentity ? 1 : 0.8) }
                    }
                }.scrollTargetLayout()
            }.contentMargins(.horizontal, 22).scrollTargetBehavior(.viewAligned).scrollPosition(id: $focused)
            HStack(spacing: 5) { ForEach(events) { event in Capsule().fill(event.id == (focused ?? events.first?.id) ? Color.accentGreen : Color.accentGreen.opacity(0.13)).frame(width: event.id == (focused ?? events.first?.id) ? 24 : 6, height: 4) } }
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: focused).accessibilityHidden(true)
        }
    }
}
struct HostView: View {
    @Environment(AppStore.self) private var store
    var host: String
    @State private var selected: CampusEvent?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HostAvatar(name: host, size: 78); Text(host).font(.largeTitle.bold())
                Text(store.space == .campus ? "在校园，和有趣的人做有意思的事。" : "在长沙，遇见更多志同道合的人。").foregroundStyle(.secondary)
                Button { store.follow(host) } label: { Label(store.state.followedHosts.contains(host) ? "已关注" : "关注组织", systemImage: store.state.followedHosts.contains(host) ? "checkmark" : "plus").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton())
                Text("即将举办").font(.title3.bold())
                ForEach(store.events.filter { $0.host == host }) { event in Button { selected = event } label: { EventRow(event: event) }.buttonStyle(SoftPressStyle()) }
            }.padding(24)
        }.background(Color.paper).navigationBarTitleDisplayMode(.inline).sheet(item: $selected) { EventDetailView(eventID: $0.id).appSheet() }
    }
}
