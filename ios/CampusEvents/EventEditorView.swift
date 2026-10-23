import SwiftUI
import PhotosUI

struct EventEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: CampusEvent? = nil
    @State private var title = ""
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
    @State private var coverPicker: PhotosPickerItem?
    @State private var groupPicker: PhotosPickerItem?
    @State private var group = EventGroup()
    @State private var groupEnabled = false
    @State private var agenda = ""
    @State private var localError: String?
    @State private var loaded = false
    @State private var loadingImage = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 15) {
                        Group { if let imageData, let image = UIImage(data: imageData) { Image(uiImage: image).resizable() } else { Image(cover).resizable() } }.scaledToFill().frame(height: 225).clipped().clipShape(RoundedRectangle(cornerRadius: 19))
                        HStack(spacing: 12) {
                            ForEach(["weekend", "music", "tech"], id: \.self) { name in Button { cover = name; imageData = nil } label: { Image(name).resizable().scaledToFill().frame(width: 52, height: 52).clipped().clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(cover == name && imageData == nil ? Color.accentGreen : .clear, lineWidth: 3)) }.buttonStyle(.plain).accessibilityLabel("选择\(name)海报") }
                            Spacer()
                            PhotosPicker(selection: $coverPicker, matching: .images) { Image(systemName: "photo.badge.plus").font(.title2).frame(width: 52, height: 52).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10)) }.accessibilityLabel("上传活动海报")
                        }
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                Section("活动内容") {
                    TextField("活动名称", text: $title).font(.headline).accessibilityIdentifier("editor.title")
                    TextField("一句话介绍", text: $summary).accessibilityIdentifier("editor.summary")
                    TextField("活动详情、参与要求和注意事项", text: $description, axis: .vertical).lineLimit(4...10).accessibilityIdentifier("editor.description")
                    Picker("活动分类", selection: $category) { ForEach(Category.allCases.filter { $0 != .all }) { Text($0.rawValue).tag($0) } }
                }
                Section("时间与地点") {
                    DatePicker("开始时间", selection: $start, in: Date()...)
                    DatePicker("结束时间", selection: $end, in: start...)
                    DatePicker("报名截止", selection: $deadline)
                    Picker("校区", selection: $campus) { ForEach(Campus.allCases.filter { $0 != .all }) { Text($0.rawValue).tag($0) } }
                    TextField("具体地点 / 集合位置", text: $location).accessibilityIdentifier("editor.location")
                }
                Section("主办与报名") {
                    TextField("主办方名称", text: $host).accessibilityIdentifier("editor.host")
                    Stepper("人数上限：\(capacity) 人", value: $capacity, in: 1...10000, step: 5)
                    Toggle("报名需要审核", isOn: $approval)
                    Toggle("名额满后允许候补", isOn: $waitlist)
                }
                Section("活动安排") { TextField("每行写一项，例如：14:00 集合签到", text: $agenda, axis: .vertical).lineLimit(3...8) }
                Section("活动群") {
                    Toggle("添加活动交流群", isOn: $groupEnabled).accessibilityIdentifier("editor.groupEnabled")
                    if groupEnabled {
                        TextField("群名称", text: $group.name)
                        Picker("平台", selection: $group.platform) { Text("微信").tag("微信"); Text("QQ").tag("QQ") }
                        PhotosPicker(selection: $groupPicker, matching: .images) { Label(group.imageData == nil ? "上传群二维码图片" : "更换群二维码图片", systemImage: "qrcode") }
                        if let data = group.imageData, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).frame(maxWidth: .infinity)
                            Button("移除二维码", role: .destructive) { group.imageData = nil }
                        }
                        TextField("群链接（选填，https://）", text: $group.link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("editor.groupLink")
                        TextField("入群说明", text: $group.notice, axis: .vertical).lineLimit(2...5)
                        Toggle("仅报名成功后可查看", isOn: $group.membersOnly)
                    }
                }
                Section("综测") { LabeledContent("计分规则", value: existing.map { $0.creditHundredths > 0 ? "+\($0.creditText) 分" : "待老师设置" } ?? "待老师设置") }
                if loadingImage { ProgressView("正在处理图片…") }
                Section {
                    Button { save() } label: { Text(existing == nil ? "发布活动" : "保存修改").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).listRowInsets(EdgeInsets()).listRowBackground(Color.clear).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingImage).accessibilityIdentifier("editor.publish")
                }
            }.navigationTitle(existing == nil ? "创建活动" : "编辑活动").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } } }
                .onAppear { load() }
                .onChange(of: start) { old, new in end = max(end.addingTimeInterval(new.timeIntervalSince(old)), new.addingTimeInterval(3600)); deadline = min(deadline.addingTimeInterval(new.timeIntervalSince(old)), new) }
                .onChange(of: coverPicker) { _, item in Task { await loadImage(item, isGroup: false) } }
                .onChange(of: groupPicker) { _, item in Task { await loadImage(item, isGroup: true) } }
                .alert("请检查活动信息", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("知道了") { localError = nil } } message: { Text(localError ?? "") }
        }
    }
    func load() {
        guard !loaded else { return }; loaded = true
        host = store.profile.name
        if let e = existing { title = e.title; summary = e.summary; description = e.description; location = e.location; host = e.host; campus = e.campus; category = e.category; start = e.start; end = e.end; deadline = e.deadline; capacity = e.capacity; approval = e.requiresApproval; waitlist = e.allowWaitlist; cover = e.cover; imageData = e.imageData; group = e.group; groupEnabled = e.group.available; agenda = e.agenda.joined(separator: "\n") }
    }
    func loadImage(_ item: PhotosPickerItem?, isGroup: Bool) async {
        guard let item else { return }
        loadingImage = true; defer { loadingImage = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), data.count <= 25_000_000, let image = UIImage(data: data) else { localError = "请选择小于 25 MB 的图片。"; return }
            let scale = min(1, 1800 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)); image.draw(in: CGRect(origin: .zero, size: size)) }
            if isGroup { group.imageData = normalized.pngData() } else { imageData = normalized.jpegData(compressionQuality: 0.85) }
        } catch { localError = "图片读取失败，请重新选择。" }
    }
    func save() {
        if !store.state.consented { localError = "请先在「我的 → 校园身份」中阅读并同意服务说明，再发布活动。"; return }
        var event = existing ?? CampusEvent(title: title, summary: summary, description: description, category: category, location: location, start: start, end: end, deadline: deadline, hostID: store.profile.id, host: host, cover: cover)
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines); event.summary = summary; event.description = description; event.category = category; event.campus = campus; event.location = location; event.start = start; event.end = end; event.deadline = deadline; event.host = host.isEmpty ? store.profile.name : host; event.cover = cover; event.imageData = imageData; event.capacity = capacity; event.requiresApproval = approval; event.allowWaitlist = waitlist; event.group = groupEnabled ? group : EventGroup(); event.agenda = agenda.split(separator: "\n").map(String.init)
        do { try EventRules.validate(event) } catch { localError = error.localizedDescription; return }
        if store.publish(event) { dismiss() } else { localError = store.error; store.error = nil }
    }
}
