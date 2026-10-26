import SwiftUI

struct EventEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    var existing: CampusEvent? = nil
    @State private var title = ""
    @State private var space = ActivitySpace.campus
    @State private var allSchools = true
    @State private var audience = Set<String>()
    @State private var topics = Set<Interest>()
    @State private var discard = false
    @State private var preview = false
    @State private var published = false
    @State private var summary = ""
    @State private var description = ""
    @State private var location = ""
    @State private var host = ""
    @State private var campus = Campus.yuntang
    @State private var category = Category.culture
    @State private var start = Date().addingTimeInterval(86400)
    @State private var end = Date().addingTimeInterval(93600)
    @State private var deadline = Date().addingTimeInterval(82800)
    @State private var capacity = 60
    @State private var approval = false
    @State private var waitlist = true
    @State private var cover = "weekend"
    @State private var imageData: Data?
    @State private var group = EventGroup()
    @State private var groupEnabled = false
    @State private var agenda = ""
    @State private var localError: String?
    @State private var attempted = false
    @State private var loaded = false
    @State private var initialDraft: CampusEvent?
    @State private var draftID = UUID()
    var draft: CampusEvent {
        var e = existing ?? CampusEvent(title: title, summary: summary, description: description, category: category, location: location, start: start, end: end, deadline: deadline, hostID: store.profile.id, host: host, cover: cover)
        e.id = existing?.id ?? draftID; e.schoolID = existing?.schoolID ?? store.school.id
        e.access = EventAccess(space: space, audienceSchoolIDs: space == .city && !allSchools ? audience : [])
        e.interestTags = topics
        if space == .city { e.creditHundredths = 0; e.creditMode = .review }
        e.title = title.trimmingCharacters(in: .whitespacesAndNewlines); e.summary = summary; e.description = description; e.category = category; e.campus = campus; e.location = location; e.start = start; e.end = end; e.deadline = deadline; e.host = host.isEmpty ? store.profile.name : host; e.cover = cover; e.imageData = imageData; e.capacity = capacity; e.requiresApproval = approval; e.allowWaitlist = waitlist; e.group = groupEnabled ? group : EventGroup(); e.agenda = agenda.split(separator: "\n").map(String.init)
        return e
    }
    var errors: [DraftField: String] { FormValidation.event(draft, needsAudience: space == .city && !allSchools, allowPastStart: existing?.start == start) }
    var dirty: Bool { loaded && initialDraft != draft }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    scopeSection
                    coverSection
                    contentSection
                    datesSection
                    hostSection
                    interestsSection
                    Section("活动安排") { TextField("每行一项，例如：14:00 集合签到", text: $agenda, axis: .vertical).lineLimit(3...8) }
                    groupSection
                    if space == .campus { Section("综测") { LabeledContent("计分规则", value: existing.map { $0.creditHundredths > 0 ? "+\($0.creditText) 分" : "待老师设置" } ?? "待老师设置") } }
                }.scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively).background(Color.paper)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        VStack(spacing: 10) {
                            InlineAlert(message: localError)
                            if attempted && !errors.isEmpty { Text("还有 \(errors.count) 项需要完善").font(.caption).foregroundStyle(.red) }
                            HStack(spacing: 12) {
                                Button("取消") { cancel() }.buttonStyle(QuietButton()).frame(width: 72)
                                if existing == nil {
                                    Button { if validate(proxy) { preview = true } } label: { Label("预览并发布", systemImage: "arrow.right").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("editor.publish")
                                } else {
                                    CompletionButton(title: "保存修改", action: { validate(proxy) && save() }, completed: { dismiss() }).accessibilityIdentifier("editor.publish")
                                }
                            }
                        }.padding(.horizontal, 20).padding(.vertical, 12).background(.regularMaterial)
                    }
            }.navigationTitle(existing == nil ? "创建活动" : "编辑活动").navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(dirty)
                .bottomActions("放弃尚未保存的编辑？", isPresented: $discard, cancelTitle: "继续编辑", actions: [SheetAction("放弃编辑", role: .destructive) { dismiss() }])
                .sheet(isPresented: $preview, onDismiss: { if published { dismiss() } }) { publishPreview.appSheet(SheetSize.tall) }
                .onAppear { load() }
        }
    }
    var scopeSection: some View {
        Section {
            Picker("发布空间", selection: $space) { ForEach(ActivitySpace.allCases) { Text($0 == .campus ? "校内活动" : "长沙开放活动").tag($0) } }.pickerStyle(.segmented).disabled(existing != nil)
            LabeledContent("主办学校", value: existing?.schoolName ?? store.school.name)
            if space == .city {
                Toggle("面向长沙各高校学生", isOn: $allSchools).disabled(existing != nil)
                if !allSchools { ForEach(School.all) { school in Toggle(school.name, isOn: Binding(get: { audience.contains(school.id) }, set: { if $0 { audience.insert(school.id) } else { audience.remove(school.id) } })).disabled(existing != nil) } }
                fieldError(.audience)
            } else { LabeledContent("报名对象", value: "仅本校已验证学生") }
        } header: { Text("活动范围") } footer: { if existing != nil { Text("已发布活动的空间与报名学校保持不变。") } }.id(DraftField.audience)
    }
    var coverSection: some View {
        Section {
            VStack(spacing: 15) {
                EventCover(event: draft).frame(height: 210).clipped().clipShape(RoundedRectangle(cornerRadius: 22))
                HStack(spacing: 12) {
                    ForEach(["weekend", "music", "tech"], id: \.self) { name in Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { cover = name; imageData = nil } } label: { Image(name).resizable().scaledToFill().frame(width: 52, height: 52).clipped().clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(cover == name && imageData == nil ? Color.accentGreen : .clear, lineWidth: 2)) }.buttonStyle(SoftPressStyle()).accessibilityLabel("选择\(name)海报") }
                    Spacer()
                    MediaPickerButton(data: $imageData) { Image(systemName: "photo.badge.plus").font(.title2).frame(width: 52, height: 52).background(.white, in: RoundedRectangle(cornerRadius: 12)) }.accessibilityLabel("活动海报操作")
                }
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
    }
    var contentSection: some View {
        Section("活动内容") {
            VStack(alignment: .leading) { TextField("活动名称", text: $title).font(.headline).accessibilityIdentifier("editor.title"); fieldError(.title) }.id(DraftField.title)
            TextField("一句话介绍", text: $summary).accessibilityIdentifier("editor.summary")
            TextField("活动详情、参与要求和注意事项", text: $description, axis: .vertical).lineLimit(4...8).accessibilityIdentifier("editor.description")
            Picker("活动分类", selection: $category) { ForEach(Category.allCases.filter { $0 != .all }) { Text($0.rawValue).tag($0) } }
        }
    }
    var datesSection: some View {
        Section("时间与地点") {
            VStack(alignment: .leading) { DateWheelRow(title: "开始时间", value: $start); fieldError(.start) }.id(DraftField.start)
            VStack(alignment: .leading) { DateWheelRow(title: "结束时间", value: $end); fieldError(.end) }.id(DraftField.end)
            VStack(alignment: .leading) { DateWheelRow(title: "报名截止", value: $deadline); fieldError(.deadline) }.id(DraftField.deadline)
            if space == .campus && store.school.id == "csust" { Picker("校区", selection: $campus) { ForEach(Campus.allCases.filter { $0 != .all }) { Text($0.rawValue).tag($0) } } }
            VStack(alignment: .leading) { TextField("具体地点 / 集合位置", text: $location).accessibilityIdentifier("editor.location"); fieldError(.location) }.id(DraftField.location)
        }
    }
    var hostSection: some View {
        Section("主办与报名") {
            TextField("主办方名称", text: $host).accessibilityIdentifier("editor.host")
            Stepper("人数上限：\(capacity) 人", value: $capacity, in: 1...10000).contentTransition(.numericText())
            fieldError(.capacity).id(DraftField.capacity)
            Toggle("报名需要审核", isOn: $approval); Toggle("名额满后允许候补", isOn: $waitlist)
        }
    }
    var interestsSection: some View {
        Section("兴趣标签") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Interest.allCases) { interest in
                    Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { if topics.contains(interest) { topics.remove(interest) } else { topics.insert(interest) } } } label: {
                        HStack(spacing: 6) { Image(systemName: interest.symbol); Text(interest.title); Spacer(minLength: 0); Image(systemName: topics.contains(interest) ? "checkmark.circle.fill" : "circle") }.font(.caption.weight(.medium)).padding(11).frame(minHeight: 44).foregroundStyle(topics.contains(interest) ? Color.accentGreen : .secondary).background(topics.contains(interest) ? Color.accentGreen.opacity(0.09) : Color.paper, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(SoftPressStyle()).accessibilityAddTraits(topics.contains(interest) ? .isSelected : [])
                }
            }.padding(.vertical, 8)
        }
    }
    var groupSection: some View {
        Section("活动群") {
            Toggle("添加活动交流群", isOn: $groupEnabled).accessibilityIdentifier("editor.groupEnabled")
            if groupEnabled {
                TextField("群名称", text: $group.name)
                Picker("平台", selection: $group.platform) { Text("微信").tag("微信"); Text("QQ").tag("QQ") }
                MediaPickerButton(data: $group.imageData, png: true) { Label(group.imageData == nil ? "添加群二维码" : "群二维码操作", systemImage: "qrcode").frame(minHeight: 44) }
                if let data = group.imageData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160).frame(maxWidth: .infinity) }
                VStack(alignment: .leading) { TextField("群链接（选填，https://）", text: $group.link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("editor.groupLink"); fieldError(.groupLink) }.id(DraftField.groupLink)
                TextField("入群说明", text: $group.notice, axis: .vertical).lineLimit(2...5)
                Toggle("仅报名成功后可查看", isOn: $group.membersOnly)
            }
        }
    }
    var publishPreview: some View {
        NavigationStack {
            List {
                Section { Text(title).font(.title2.bold()).padding(.vertical, 12) }
                Section("活动将发布到") {
                    LabeledContent("空间", value: space == .campus ? store.school.name + " · 校园" : "长沙开放活动")
                    LabeledContent("报名对象", value: draft.audienceText)
                    LabeledContent("讨论群", value: "本场活动获准参加的同学")
                    LabeledContent("综测", value: space == .campus ? "由本校老师设置" : "由参加者所属学校另行认定")
                    LabeledContent("开始时间", value: start.formatted(date: .abbreviated, time: .shortened))
                }
                if let localError { Section { InlineAlert(message: localError) } }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle("发布预览").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 11) {
                        CompletionButton(title: "确认发布", symbol: "paperplane", action: { let ok = save(); published = ok; return ok }, completed: { preview = false })
                        Button("返回编辑") { preview = false }.buttonStyle(QuietButton())
                    }.padding(20).background(.regularMaterial)
                }
        }.interactiveDismissDisabled(published)
    }
    func fieldError(_ field: DraftField) -> some View { InlineAlert(message: attempted ? errors[field] : nil) }
    func validate(_ proxy: ScrollViewProxy) -> Bool {
        attempted = true
        guard errors.isEmpty else { if let first = DraftField.allCases.first(where: { errors[$0] != nil }) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo(first, anchor: .center) } }; return false }
        return true
    }
    func cancel() { if dirty { discard = true } else { dismiss() } }
    func load() {
        guard !loaded else { return }
        host = store.profile.name; space = store.space; audience = [store.school.id]
        if let e = existing { title = e.title; summary = e.summary; description = e.description; location = e.location; host = e.host; campus = e.campus; category = e.category; start = e.start; end = e.end; deadline = e.deadline; capacity = e.capacity; approval = e.requiresApproval; waitlist = e.allowWaitlist; cover = e.cover; imageData = e.imageData; group = e.group; groupEnabled = e.group.available; agenda = e.agenda.joined(separator: "\n"); space = e.space; audience = e.audienceSchoolIDs; allSchools = audience.isEmpty; topics = e.topics }
        initialDraft = draft; loaded = true
    }
    func save() -> Bool {
        attempted = true
        guard errors.isEmpty else { localError = "请返回编辑，修正标红的字段。"; return false }
        if !store.state.consented { localError = "请先在个人资料中阅读并同意服务说明。"; return false }
        if store.publish(draft) { localError = nil; return true }
        localError = store.error; store.error = nil; return false
    }
}
