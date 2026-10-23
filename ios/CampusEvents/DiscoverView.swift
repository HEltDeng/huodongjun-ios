import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var schools = false
    @State private var interests = false
    @State private var recommended = true
    @State private var path = NavigationPath()
    @State private var searchVisible = false
    @State private var category: Category = .all
    @State private var campus: Campus = .all
    @State private var availableOnly = false
    @State private var filters = false
    @State private var create = false
    @State private var selected: CampusEvent?
    var filtered: [CampusEvent] {
        let source = recommended && !SpaceRules.verifiedSchools(store.state).isEmpty ? store.ranked(store.events) : store.events
        return source.filter { event in
            (category == .all || category == event.category) && (store.space == .city || store.school.id != "csust" || campus == .all || campus == event.campus) &&
            (!availableOnly || (event.deadline > Date() && store.count(event) < event.capacity)) &&
            (search.isEmpty || "\(event.title)\(event.host)\(event.location)\(event.description)".localizedCaseInsensitiveContains(search))
        }
    }
    var featured: [CampusEvent] {
        var covers = Set<String>()
        let varied = filtered.filter { covers.insert($0.imageData == nil ? $0.cover : $0.id.uuidString).inserted }
        return Array((varied + filtered.filter { event in !varied.contains(where: { $0.id == event.id }) }).prefix(3))
    }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    SpaceSwitcher().padding(.horizontal, 22)
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.space == .campus ? "发现校园" : "发现长沙").font(.system(size: 34, weight: .bold))
                            Button { if store.space == .campus { schools = true } else { filters = true } } label: { HStack(spacing: 5) { Image(systemName: "location.fill").font(.caption2); Text(store.space == .campus ? store.school.name + (campus == .all ? "" : " · " + campus.rawValue) : "长沙 · 高校开放活动"); Image(systemName: "chevron.down").font(.caption2) }.font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { searchVisible.toggle() }; if !searchVisible { search = "" } } label: { Image(systemName: "magnifyingglass").font(.title3).frame(width: 44, height: 44).background(.white, in: Circle()) }.buttonStyle(SoftPressStyle()).accessibilityLabel("搜索活动").accessibilityIdentifier("discover.search")
                        Button { create = true } label: { Image(systemName: "plus").font(.title3).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.ink, in: Circle()) }.buttonStyle(SoftPressStyle()).accessibilityLabel("创建活动").accessibilityIdentifier("discover.create")
                    }.padding(.horizontal, 22)
                    if searchVisible {
                        HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("搜索活动、地点或主办方", text: $search).submitLabel(.search).accessibilityIdentifier("discover.searchField"); if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } } }.padding(13).background(.white, in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 22)
                    }
                    HStack(spacing: 8) {
                        Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { recommended = true } } label: { Text("为你推荐").font(.subheadline.weight(recommended ? .semibold : .regular)).foregroundStyle(recommended ? Color.ink : .secondary) }.buttonStyle(SoftPressStyle())
                        Text("/").foregroundStyle(.tertiary)
                        Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { recommended = false } } label: { Text("全部活动").font(.subheadline.weight(recommended ? .regular : .semibold)).foregroundStyle(recommended ? Color.secondary : .ink) }.buttonStyle(SoftPressStyle())
                        Spacer()
                        Button { interests = true } label: { Label("兴趣", systemImage: "slider.horizontal.3").font(.caption.weight(.medium)).foregroundStyle(Color.accentGreen).padding(9).background(Color.accentGreen.opacity(0.065), in: Capsule()) }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("discover.interests")
                    }.padding(.horizontal, 22)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(Category.allCases) { item in
                                Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { category = item } } label: {
                                    Label(item.rawValue, systemImage: item.symbol).font(.system(size: 13, weight: .medium)).padding(.horizontal, 14).padding(.vertical, 11).foregroundStyle(category == item ? .white : Color.primary).background(category == item ? Color.ink : .white, in: Capsule())
                                }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("category.\(item.rawValue)")
                            }
                        }.padding(.horizontal, 22)
                    }
                    if store.space == .campus && !store.schoolVerified { CampusAccessPrompt() }
                    else if filtered.isEmpty { EmptyState(symbol: "magnifyingglass", title: "暂时没有找到活动", subtitle: "换个关键词，或试试其他分类。") }
                    else {
                        if category == .all && search.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack { Text(recommended ? "为你精选" : store.space == .campus ? "校园精选" : "长沙精选").font(.title3.bold()); Spacer(); Text("一起，才有意思").font(.caption).foregroundStyle(.secondary) }.padding(.horizontal, 22)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .top, spacing: 15) {
                                        ForEach(featured) { event in
                                            Button { selected = event } label: {
                                                VStack(alignment: .leading, spacing: 12) {
                                                    EventCover(event: event).frame(width: 268, height: 268).clipped().clipShape(RoundedRectangle(cornerRadius: 23))
                                                    Text(event.start.formatted(.dateTime.month().day().weekday().hour().minute())).font(.caption.weight(.medium)).foregroundStyle(Color.accentGreen)
                                                    Text(event.title).font(.system(size: 18, weight: .bold)).foregroundStyle(.primary).lineLimit(1)
                                                    HStack(spacing: 6) { HostAvatar(name: event.host, size: 20); Text(event.host).font(.caption).foregroundStyle(.secondary); Spacer(); if event.space == .campus && event.creditHundredths > 0 { Tag(text: "+\(event.creditText) 综测") } }
                                                }.frame(width: 268, alignment: .leading)
                                            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("featured.\(event.cover)")
                                        }
                                    }.padding(.horizontal, 22)
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text(search.isEmpty ? "即将发生" : "搜索结果").font(.title3.bold()); Spacer(); Button { filters = true } label: { Label("筛选", systemImage: "slider.horizontal.3").font(.caption).foregroundStyle(.secondary) } }
                            ForEach(filtered) { event in Button { selected = event } label: { EventRow(event: event) }.buttonStyle(SoftPressStyle()); if event.id != filtered.last?.id { Divider().opacity(0.5) } }
                        }.padding(.horizontal, 22)
                        if category == .all && search.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("找到你的同好").font(.title3.bold())
                                ForEach(Array(Set(store.events.map(\.host))).sorted(), id: \.self) { host in
                                    NavigationLink { HostView(host: host) } label: {
                                        HStack { HostAvatar(name: host, size: 42); VStack(alignment: .leading, spacing: 4) { Text(host).font(.subheadline.weight(.semibold)); Text(store.space == .campus ? store.school.name + " · 校园组织" : "长沙 · 活动主办方").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }.padding(13).background(.white, in: RoundedRectangle(cornerRadius: 17))
                                    }.buttonStyle(SoftPressStyle())
                                }
                            }.padding(.horizontal, 22)
                        }
                    }
                }.padding(.top, 14).padding(.bottom, 28)
            }.background(Color.paper).toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selected) { EventDetailView(eventID: $0.id) }
            .sheet(isPresented: $create) { EventEditorView() }
            .sheet(isPresented: $schools) { SchoolPickerView() }
            .sheet(isPresented: $interests) { InterestSelectionView() }
            .onChange(of: store.contextID) { _, _ in path = NavigationPath(); selected = nil; campus = .all; category = .all; search = ""; filters = false }
            .sheet(isPresented: $filters) {
                NavigationStack {
                    Form {
                        if store.space == .campus && store.school.id == "csust" { Section("校区") { Picker("选择校区", selection: $campus) { ForEach(Campus.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline).labelsHidden() } }
                        Section { Toggle("仅看仍有名额的活动", isOn: $availableOnly) }
                    }.navigationTitle("筛选活动").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("重置") { campus = .all; availableOnly = false; category = .all } }; ToolbarItem(placement: .topBarTrailing) { Button("完成") { filters = false } } }
                }.presentationDetents([.medium])
            }
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
                HostAvatar(name: host, size: 78)
                Text(host).font(.largeTitle.bold())
                Text(store.space == .campus ? "在校园，和有趣的人做有意思的事。" : "在长沙，遇见更多志同道合的人。").foregroundStyle(.secondary)
                Button { store.follow(host) } label: { Label(store.state.followedHosts.contains(host) ? "已关注" : "关注组织", systemImage: store.state.followedHosts.contains(host) ? "checkmark" : "plus").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton())
                Text("即将举办").font(.title3.bold())
                ForEach(store.events.filter { $0.host == host }) { event in Button { selected = event } label: { EventRow(event: event) }.buttonStyle(SoftPressStyle()) }
            }.padding(24)
        }.background(Color.paper).navigationBarTitleDisplayMode(.inline).sheet(item: $selected) { EventDetailView(eventID: $0.id) }
    }
}
