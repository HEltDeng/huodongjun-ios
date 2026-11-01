import SwiftUI
import SafariServices

private let competitionRed = Color(red: 0.77, green: 0.32, blue: 0.26)
private let competitionGreen = Color(red: 0.23, green: 0.52, blue: 0.36)

struct CompetitionsView: View {
    @State private var store = CompetitionStore()
    @State private var city = "All"
    @State private var mode = "赛场"
    @State private var search = ""
    @State private var status = "全部状态"
    @State private var savedOnly = false
    @State private var selected: OfficialCompetition?
    @State private var information = false
    @State private var month = CompetitionDates.calendar.dateInterval(of: .month, for: Date())!.start
    @State private var day: Date?
    private var currentRegion: CompetitionRegion? { store.regions.first { $0.key == "China" } }
    private var cities: [CompetitionCity] {
        let priority = ["Beijing", "Shanghai", "Changsha", "Online"]
        return (currentRegion?.cities ?? []).sorted { a, b in
            let left = priority.firstIndex(of: a.key) ?? 4, right = priority.firstIndex(of: b.key) ?? 4
            return left == right ? a.key < b.key : left < right
        }
    }
    private var filtered: [OfficialCompetition] {
        store.items.filter {
            (status == "全部状态" || $0.phase().rawValue == status) &&
            (!savedOnly || store.favorites.contains($0.id)) &&
            (search.isEmpty || "\($0.title) \($0.location) \($0.platform) \($0.tags.joined(separator: " "))".localizedCaseInsensitiveContains(search))
        }.sorted { a, b in
            let order: [CompetitionPhase: Int] = [.ongoing: 0, .upcoming: 1, .unknown: 2, .ended: 3]
            let left = order[a.phase()]!, right = order[b.phase()]!
            if left != right { return left < right }
            if a.end != b.end { return (a.end ?? .distantFuture) < (b.end ?? .distantFuture) }
            return a.id < b.id
        }
    }
    private var calendarItems: [OfficialCompetition] {
        filtered.filter { item in day.map { item.milestone(on: $0) != nil } ?? item.overlaps(month: month) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    regionPicker
                    Picker("赛事展示方式", selection: $mode) {
                        Text("赛场").tag("赛场")
                        Text("赛事日历").tag("赛事日历")
                    }.pickerStyle(.segmented).accessibilityIdentifier("competitions.mode")
                    searchAndFilters
                    if let error = store.error {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                            Text(error).font(.subheadline)
                            Spacer(minLength: 0)
                            Button("重试") { Task { await store.load(city: city, force: true) } }.font(.subheadline.bold())
                        }.foregroundStyle(Color.ink).padding(15).background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if store.isLoading && store.items.isEmpty {
                        ProgressView("正在查找赛事").frame(maxWidth: .infinity).padding(.vertical, 70)
                    } else if mode == "赛事日历" {
                        calendarContent
                    } else {
                        HStack {
                            Text(savedOnly ? "收藏的赛事" : "探索赛场").font(.title3.bold())
                            Spacer()
                            if store.isHydrating { ProgressView().controlSize(.small) }
                            Text("\(filtered.count) 场").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        if filtered.isEmpty { emptyState }
                        LazyVStack(spacing: 14) { ForEach(filtered) { item in competitionButton(item) } }
                    }
                    if store.nextURL != nil {
                        Button { Task { await store.loadMore() } } label: {
                            HStack { if store.isLoading { ProgressView() }; Text("加载更多赛事"); Image(systemName: "arrow.down") }.frame(maxWidth: .infinity)
                        }.buttonStyle(QuietButton()).disabled(store.isLoading || store.isHydrating)
                    }
                }.padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 24)
            }.background(Color.paper).scrollDismissesKeyboard(.interactively).toolbar(.hidden, for: .navigationBar)
                .refreshable { await store.load(city: city, force: true) }
                .task(id: city) { await store.load(city: city) }
                .sheet(item: $selected) { CompetitionDetailView(initial: $0, store: store).appSheet(.large) }
                .sheet(isPresented: $information) { CompetitionSourceView(updatedAt: store.updatedAt).appSheet() }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("CHINA · AI COMPETITIONS").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(Color.accentGreen)
                    Text("官方赛事").font(.system(size: 30, weight: .bold))
                }
                Spacer()
                Button { information = true } label: { Image(systemName: "info").font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44).background(.white, in: Circle()) }.buttonStyle(SoftPressStyle()).accessibilityLabel("赛事来源与说明")
            }
            HStack(spacing: 15) {
                Image(systemName: "trophy").font(.system(size: 28, weight: .light)).frame(width: 58, height: 64).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 8) {
                    Text("中国赛场").font(.system(size: 17, weight: .semibold))
                    HStack(spacing: 7) {
                        Circle().fill(Color(red: 0.65, green: 0.85, blue: 0.54)).frame(width: 6, height: 6)
                        Text(store.isLoading && store.items.isEmpty ? "正在读取中国赛事" : "\(store.items.filter { $0.phase() == .ongoing }.count) 场进行中 · \(store.items.count) 场已载入")
                            .font(.caption).foregroundStyle(.white.opacity(0.8)).contentTransition(.numericText())
                    }
                }
                Spacer(minLength: 0)
            }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color.ink, Color.accentGreen], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
            if store.isCached, let date = store.updatedAt {
                Label("已保存的赛事 · \(CompetitionDates.text(date))更新", systemImage: "clock.arrow.circlepath").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var regionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("中国", systemImage: "mappin.and.ellipse").font(.subheadline.bold())
                Spacer()
                if city != "All", let selectedCity = cities.first(where: { $0.key == city }) {
                    Text(selectedCity.name).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    cityChip("全部", key: "All")
                    ForEach(cities) { item in cityChip(item.name, key: item.key) }
                }
            }
        }
    }
    private func cityChip(_ title: String, key: String) -> some View {
        Button { city = key; day = nil } label: {
            Text(title).font(.system(size: 13, weight: city == key ? .semibold : .regular)).padding(.horizontal, 14).frame(minHeight: 40)
                .foregroundStyle(city == key ? Color.accentGreen : .secondary)
                .background(city == key ? Color.accentGreen.opacity(0.1) : .clear, in: Capsule())
        }.buttonStyle(SoftPressStyle()).accessibilityAddTraits(city == key ? .isSelected : []).accessibilityIdentifier("competitions.city.\(key)")
    }
    private var searchAndFilters: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索赛事、城市、平台", text: $search).font(.subheadline).submitLabel(.search).accessibilityIdentifier("competitions.search")
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("清除赛事搜索") }
            }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
            HStack {
                Menu {
                    Picker("赛事状态", selection: $status) {
                        Text("全部状态").tag("全部状态")
                        ForEach(CompetitionPhase.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                } label: { Label(status, systemImage: "line.3.horizontal.decrease").font(.subheadline).frame(minHeight: 40) }
                Spacer()
                Button { savedOnly.toggle() } label: { Label("收藏", systemImage: savedOnly ? "bookmark.fill" : "bookmark").font(.subheadline).frame(minHeight: 40).foregroundStyle(savedOnly ? Color.accentGreen : Color.secondary) }.buttonStyle(SoftPressStyle()).accessibilityAddTraits(savedOnly ? .isSelected : [])
            }
        }
    }
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy").font(.system(size: 32, weight: .light)).foregroundStyle(Color.accentGreen)
            Text(savedOnly ? "还没有收藏的赛事" : (cities.first(where: { $0.key == city })?.name ?? "中国") + "暂时没有赛事").font(.headline)
            Button("查看中国全部赛事") { search = ""; status = "全部状态"; savedOnly = false; city = "All"; day = nil }.font(.subheadline).frame(minHeight: 44)
        }.frame(maxWidth: .infinity).padding(.vertical, 35)
    }
    private func competitionButton(_ item: OfficialCompetition, milestone: String? = nil) -> some View {
        Button { selected = item } label: {
            CompetitionCard(item: item, favorite: store.favorites.contains(item.id), milestone: milestone)
        }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("competition.\(item.id)")
    }
    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            CompetitionCalendar(month: $month, day: $day, items: filtered)
            HStack {
                Text(day.map { CompetitionDates.text($0) + " · 关键节点" } ?? "本月赛程").font(.title3.bold())
                Spacer()
                if day != nil { Button("整月") { day = nil }.font(.subheadline) }
                Text("\(calendarItems.count) 场").font(.subheadline).foregroundStyle(.secondary)
            }
            if store.isHydrating { ProgressView("正在更新赛程").font(.caption) }
            if calendarItems.isEmpty {
                ContentUnavailableView(day == nil ? "本月暂无赛程" : "当天没有开始或结束的赛事", systemImage: "calendar", description: Text("选择其他日期，或切换地区查看。"))
            }
            ForEach(calendarItems) { item in competitionButton(item, milestone: day.flatMap { item.milestone(on: $0) }) }
            if filtered.contains(where: { !$0.validInterval }) {
                Text("\(filtered.filter { !$0.validInterval }.count) 场赛事时间待公布").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct CompetitionCard: View {
    var item: OfficialCompetition
    var favorite: Bool
    var milestone: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text(item.category).font(.caption.weight(.semibold)).foregroundStyle(Color.accentGreen)
                if let milestone { Tag(text: milestone, color: competitionRed) }
                Spacer(minLength: 0)
                if favorite { Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Color.accentGreen) }
                Text(item.phase().rawValue).font(.caption.weight(.medium)).foregroundStyle(item.phase() == .ongoing ? competitionGreen : .secondary)
            }
            Text(item.title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.ink).multilineTextAlignment(.leading).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Label(item.location, systemImage: item.location == "线上" ? "globe" : "mappin").lineLimit(1)
                Text(item.platform).lineLimit(1)
                Spacer(minLength: 0)
                if !item.prize.isEmpty && item.prize != "¥0" { Text(item.prize).fontWeight(.semibold).foregroundStyle(Color.accentGreen).lineLimit(1) }
            }.font(.caption).foregroundStyle(.secondary)
            CompetitionProgress(item: item, compact: true)
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.ink.opacity(0.045), lineWidth: 1))
    }
}

struct CompetitionProgress: View {
    var item: OfficialCompetition
    var compact = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let phase = item.phase(at: context.date)
            let progress = item.elapsed(at: context.date)
            VStack(alignment: .leading, spacing: compact ? 9 : 13) {
                HStack {
                    Text(item.timing(at: context.date)).fontWeight(.semibold).foregroundStyle(phase == .ongoing ? competitionGreen : Color.secondary)
                    Spacer()
                    if let progress {
                        Text(phase == .upcoming ? "尚未开始" : "已进行 \(Int(progress * 100))%")
                            .foregroundStyle(phase == .upcoming ? Color.secondary : competitionRed).monospacedDigit()
                    }
                }.font(compact ? .caption : .subheadline)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(phase == .ongoing ? competitionGreen.opacity(0.8) : Color.ink.opacity(0.08))
                        if let progress, progress > 0 {
                            UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: phase == .ended ? 6 : 0, topTrailingRadius: phase == .ended ? 6 : 0)
                                .fill(competitionRed).frame(width: max(0, geometry.size.width * progress))
                        }
                    }
                }.frame(height: compact ? 6 : 10).accessibilityHidden(true)
                HStack {
                    Text(CompetitionDates.text(item.start))
                    Spacer()
                    Text(CompetitionDates.text(item.end))
                }.font(.caption).foregroundStyle(.secondary)
            }.accessibilityElement(children: .combine)
        }
    }
}

private struct CompetitionCalendar: View {
    @Binding var month: Date
    @Binding var day: Date?
    var items: [OfficialCompetition]
    private let calendar = CompetitionDates.calendar
    private var offset: Int { (calendar.component(.weekday, from: month) + 5) % 7 }
    private var days: Int { calendar.range(of: .day, in: .month, for: month)?.count ?? 30 }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("上个月")
                Spacer()
                Text(month.formatted(.dateTime.year().month())).font(.headline)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("下个月")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                ForEach(0..<(offset + days), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: 44) }
                    else {
                        let date = calendar.date(byAdding: .day, value: index - offset, to: month)!
                        let selected = day.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        let starts = items.contains { $0.start.map { calendar.isDate($0, inSameDayAs: date) } ?? false }
                        let ends = items.contains { $0.end.map { calendar.isDate($0, inSameDayAs: date) } ?? false }
                        Button { day = selected ? nil : date } label: {
                            VStack(spacing: 4) {
                                Text("\(index - offset + 1)").font(.system(size: 15, weight: calendar.isDateInToday(date) ? .bold : .medium))
                                HStack(spacing: 3) {
                                    Circle().fill(starts ? (selected ? .white : competitionGreen) : .clear).frame(width: 4, height: 4)
                                    Circle().fill(ends ? (selected ? .white : competitionRed) : .clear).frame(width: 4, height: 4)
                                }
                            }.frame(maxWidth: .infinity).frame(height: 44).foregroundStyle(selected ? .white : Color.ink)
                                .background(selected ? Color.ink : calendar.isDateInToday(date) ? Color.accentGreen.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(SoftPressStyle()).accessibilityLabel(CompetitionDates.text(date) + (starts ? "，有赛事开始" : "") + (ends ? "，有赛事结束" : "")).accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            HStack(spacing: 14) {
                Label { Text("开始") } icon: { Circle().fill(competitionGreen).frame(width: 5, height: 5) }
                Label { Text("结束") } icon: { Circle().fill(competitionRed).frame(width: 5, height: 5) }
                Spacer()
                Button("今天") { month = calendar.dateInterval(of: .month, for: Date())!.start; day = Date() }
            }.font(.caption).foregroundStyle(.secondary).frame(minHeight: 35)
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 23))
    }
    private func shift(_ value: Int) { month = calendar.date(byAdding: .month, value: value, to: month)!; day = nil }
}

struct CompetitionDetailView: View {
    let initial: OfficialCompetition
    var store: CompetitionStore
    @Environment(\.dismiss) private var dismiss
    @State private var external: CompetitionWebDestination?
    @State private var refreshing = false
    @State private var source = false
    private var item: OfficialCompetition { store.item(initial.id) ?? initial }
    private var canSignUp: Bool { [1, 2].contains(item.signupStatus ?? 0) && item.phase() != .ended && item.signupURL != nil && !store.detailFailures.contains(item.id) && !refreshing }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: "trophy").font(.system(size: 28, weight: .light)).foregroundStyle(Color.accentGreen).frame(width: 64, height: 64).background(Color.accentGreen.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
                        Spacer()
                        Tag(text: item.category)
                        Tag(text: item.phase().rawValue, color: item.phase() == .ongoing ? competitionGreen : .secondary)
                    }
                    Text(item.title).font(.system(size: 28, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    Label(item.organizer?.isEmpty == false ? item.organizer! : item.platform, systemImage: "building.2").font(.subheadline).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("赛事进度").font(.headline); Spacer(); if refreshing { ProgressView() } }
                        CompetitionProgress(item: item)
                        Divider()
                        dateRow("开始日期", date: item.start, color: competitionGreen)
                        dateRow("结束日期", date: item.end, color: competitionRed)
                    }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 23))
                    if store.detailFailures.contains(item.id) {
                        HStack { Text("赛程更新失败").font(.subheadline); Spacer(); Button("重试") { Task { await refresh() } } }.padding(15).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                    }
                    VStack(alignment: .leading, spacing: 17) {
                        Text("参赛信息").font(.title3.bold())
                        informationRow("地点", value: item.location, icon: "mappin.and.ellipse")
                        if !item.prize.isEmpty && item.prize != "¥0" { informationRow("奖金", value: item.prize, icon: "gift") }
                        if item.participants > 0 { informationRow("参赛团队", value: item.participants.formatted(), icon: "person.2") }
                        informationRow("报名", value: item.registrationText, icon: "pencil.line")
                        informationRow("报名开始时间", value: "来源未提供", icon: "calendar.badge.clock")
                        if !item.tags.isEmpty { Text(item.tags.joined(separator: " · ")).font(.subheadline).foregroundStyle(Color.accentGreen).padding(.top, 3) }
                    }
                    VStack(spacing: 0) {
                        Button { external = CompetitionWebDestination(url: item.sourceURL) } label: {
                            HStack { Label("查看完整赛制与报名要求", systemImage: "doc.text"); Spacer(); Image(systemName: "arrow.up.right") }.font(.subheadline).padding(.vertical, 18)
                        }
                        Divider()
                        Button { source = true } label: {
                            HStack { Text("赛事来源"); Spacer(); Text("CompeteHub").foregroundStyle(.secondary); Image(systemName: "chevron.right").font(.caption) }.font(.subheadline).padding(.vertical, 18)
                        }
                    }
                }.padding(22)
            }.background(Color.paper).navigationTitle("赛事详情").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ShareLink(item: item.sourceURL) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("分享赛事")
                        Button { store.toggleFavorite(item.id) } label: { Image(systemName: store.favorites.contains(item.id) ? "bookmark.fill" : "bookmark") }.accessibilityLabel(store.favorites.contains(item.id) ? "取消收藏赛事" : "收藏赛事")
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button { external = CompetitionWebDestination(url: canSignUp ? item.signupURL! : item.sourceURL) } label: {
                        HStack { Text(item.phase() == .ended ? "查看赛事回顾" : canSignUp ? "前往报名" : "查看报名信息"); Image(systemName: "arrow.up.right") }.frame(maxWidth: .infinity)
                    }.buttonStyle(PrimaryButton()).padding(.horizontal, 22).padding(.vertical, 12).background(.regularMaterial)
                }
                .task { await refresh() }
                .sheet(item: $external) { CompetitionWebView(url: $0.url).ignoresSafeArea() }
                .sheet(isPresented: $source) { CompetitionSourceView(updatedAt: item.fetchedAt).appSheet() }
        }
    }
    private func refresh() async { refreshing = true; await store.refreshDetail(item); refreshing = false }
    private func dateRow(_ title: String, date: Date?, color: Color) -> some View {
        HStack { Circle().fill(color).frame(width: 7, height: 7); Text(title).foregroundStyle(.secondary); Spacer(); Text(CompetitionDates.text(date, year: true)).fontWeight(.medium) }.font(.subheadline)
    }
    private func informationRow(_ title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) { Image(systemName: icon).foregroundStyle(Color.accentGreen).frame(width: 22); Text(title).foregroundStyle(.secondary); Spacer(minLength: 10); Text(value).multilineTextAlignment(.trailing) }.font(.subheadline)
    }
}

struct CompetitionSourceView: View {
    var updatedAt: Date?
    var body: some View {
        NavigationStack {
            List {
                Section("赛事来源") {
                    Text("赛事信息来自 CompeteHub（AI赛事通）的中国地区公开页面，包含该地区收录的城市和线上赛事。“官方赛事”是活动君的赛事栏目名称，不表示活动君或 CompeteHub 是赛事主办方。具体主办方见赛事详情。")
                    Link("查看中国赛场来源", destination: CompetitionSource.feedURL())
                    if let updatedAt { LabeledContent("最近读取", value: updatedAt.formatted(date: .abbreviated, time: .shortened)) }
                }
                Section("日期与报名") {
                    Text("进度根据来源公布的开始、结束日期和当前时间计算。红色为已过去的时间，绿色为剩余时间。仅有日期时按北京时间显示，结束日期包含当天；实际截止时刻和报名资格以主办方为准。")
                    Text("比赛开始日期不等于报名开始日期。来源没有单独提供报名开始时间时显示来源未提供，请查看原赛事平台。报名在原赛事平台完成，活动君不收集或代提交报名资料。")
                }
                Section("更新与缓存") {
                    Text("打开栏目、切换城市或下拉时读取中国赛场页面。网络不可用时显示已保存的数据并标记更新时间。赛历覆盖当前赛场已载入的赛事，可通过加载更多扩展。收藏保存在本机。")
                    Text("当前使用公开页面适配，页面结构变化可能影响刷新；尚未获得官方数据接口或合作接入。请求赛事来源及打开报名页面时，目标服务会接收正常网络连接信息，不会附带活动君的校园身份资料。")
                }
            }.font(.subheadline).navigationTitle("赛事来源与说明").navigationBarTitleDisplayMode(.inline).bottomDismiss()
        }
    }
}
private struct CompetitionWebDestination: Identifiable { let id = UUID(); let url: URL }
private struct CompetitionWebView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
