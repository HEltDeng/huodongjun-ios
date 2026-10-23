import SwiftUI
import PhotosUI
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var identity = false
    @State private var service = false
    @State private var exit = false
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) { ProfileAvatar(profile: store.profile, size: 72); Spacer(); Button("编辑资料") { identity = true }.font(.caption.weight(.medium)).buttonStyle(.bordered).clipShape(Capsule()) }
                        Text(store.profile.name).font(.title.bold())
                        Text(store.profile.bio).font(.subheadline).foregroundStyle(.secondary)
                        HStack { Label("长沙理工大学", systemImage: "building.columns"); Spacer(); Text(store.profile.college).lineLimit(1) }.font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 9).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                Section {
                    NavigationLink { CreditsView() } label: { Label("我的综测", systemImage: "seal") }
                    NavigationLink { SavedEventsView() } label: { Label("收藏的活动", systemImage: "bookmark") }
                    NavigationLink { FollowedHostsView() } label: { Label("关注的组织", systemImage: "person.2") }
                    NavigationLink { HostDashboard() } label: { Label("主办方工作台", systemImage: "rectangle.stack") }
                }
                Section("账号与偏好") {
                    Button { identity = true } label: { Label("校园身份", systemImage: "person.text.rectangle") }
                    Button { Task {
                        do {
                            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                            notice = granted ? "已允许通知。远程活动提醒将在服务端接入后启用。" : "通知权限未开启，可前往系统设置修改。"
                        } catch { notice = "暂时无法请求通知权限。" }
                    } } label: { Label("通知设置", systemImage: "bell") }
                    Button { service = true } label: { Label("服务说明与隐私", systemImage: "hand.raised") }
                    NavigationLink { LocalAdminView() } label: { Label("本机管理预览", systemImage: "slider.horizontal.3") }
                }
                Section { Button("返回欢迎页") { exit = true }.frame(maxWidth: .infinity).foregroundStyle(.secondary) }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $identity) { IdentityEditor() }.sheet(isPresented: $service) { ServiceInfoView() }
                .confirmationDialog("返回欢迎页？本机活动和报名记录会保留。", isPresented: $exit, titleVisibility: .visible) { Button("返回欢迎页") { store.update { $0.onboarded = false } } }
                .alert("通知设置", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("知道了") { notice = nil } } message: { Text(notice ?? "") }
        }
    }
}

struct ProfileAvatar: View {
    var profile: StudentProfile
    var size: CGFloat
    var body: some View { if let data = profile.avatarData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()) } else { HostAvatar(name: profile.name, size: size) } }
}
struct IdentityEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var isOnboarding = false
    @State private var profile = StudentProfile()
    @State private var consent = false
    @State private var service = false
    @State private var birthdayEnabled = false
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -20, to: Date())!
    @State private var photo: PhotosPickerItem?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        PhotosPicker(selection: $photo, matching: .images) { ProfileAvatar(profile: profile, size: 76).overlay(alignment: .bottomTrailing) { Image(systemName: "camera.fill").font(.caption).foregroundStyle(.white).padding(7).background(Color.ink, in: Circle()) } }.accessibilityLabel("设置头像")
                        if isOnboarding { Text("很高兴在这里遇见你").font(.title2.bold()) }
                    }.frame(maxWidth: .infinity).padding(.vertical, 16).listRowBackground(Color.clear)
                }
                Section("个人资料") {
                    TextField("姓名 / 昵称", text: $profile.name).accessibilityIdentifier("identity.name")
                    TextField("个人简介", text: $profile.bio, axis: .vertical).lineLimit(2...4)
                    Toggle("添加生日（选填）", isOn: $birthdayEnabled)
                    if birthdayEnabled { DatePicker("生日", selection: $birthday, in: ...Date(), displayedComponents: .date) }
                }
                Section("校园身份") {
                    LabeledContent("学校", value: "长沙理工大学")
                    TextField("学号", text: $profile.studentNumber).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("identity.number")
                    TextField("学院", text: $profile.college)
                }
                Section {
                    Toggle("我已阅读并同意服务说明与隐私", isOn: $consent).font(.subheadline).accessibilityIdentifier("identity.consent")
                    Button("查看服务说明与隐私") { service = true }
                }
                Section {
                    Button {
                        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        profile.studentNumber = profile.studentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                        profile.college = profile.college.trimmingCharacters(in: .whitespacesAndNewlines)
                        profile.birthday = birthdayEnabled ? birthday : nil
                        if store.update({ $0.profile = profile; $0.consented = consent; if isOnboarding { $0.onboarded = true } }) { dismiss() }
                    } label: { Text(isOnboarding ? "进入活动君" : "保存资料").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).listRowBackground(Color.clear).listRowInsets(EdgeInsets()).disabled(!profile.complete || !consent).accessibilityIdentifier("identity.save")
                }
            }.navigationTitle(isOnboarding ? "设置个人资料" : "校园身份").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } } }
                .onAppear { profile = store.profile; consent = isOnboarding ? true : store.state.consented; birthdayEnabled = profile.birthday != nil; birthday = profile.birthday ?? birthday }
                .sheet(isPresented: $service) { ServiceInfoView() }
                .onChange(of: photo) { _, item in Task { if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data), data.count < 25_000_000 { let format = UIGraphicsImageRendererFormat(); format.scale = 1; let normalized = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { _ in let side = min(image.size.width, image.size.height); let scale = 256 / side; image.draw(in: CGRect(x: (256 - image.size.width * scale) / 2, y: (256 - image.size.height * scale) / 2, width: image.size.width * scale, height: image.size.height * scale)) }; profile.avatarData = normalized.jpegData(compressionQuality: 0.8) } } }
        }
    }
}

struct ServiceInfoView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("关于当前版本") { Text("活动君是面向长沙理工大学的校园活动应用。当前为本机开发体验版，示例活动并非学校正式发布。所有创建、报名、聊天、核销和计分操作只影响当前设备，尚未与学校系统或其他同学同步。") }
                Section("身份与综测") { Text("目前的个人资料是本机资料，不代表已通过学校身份认证。二维码是联调凭证，综测记录用于流程体验，不作为学校正式综测成绩。正式发布前将接入身份校验、教师权限、签名核销和审核记录。") }
                Section("数据与权限") { Text("资料、选填生日、报名记录和主动选择的图片保存在应用沙盒内。照片选择使用系统选择器；保存二维码时才请求添加照片权限；扫码时才请求相机权限。用户主动打开群链接或外部应用后，目标服务按其自身规则处理数据。") }
                Section("使用约定") { Text("发布活动请确保内容和图片可以使用；不要冒充校方或主办方。不要发布他人的学号、联系方式和未经许可的群二维码。取消活动需明确确认，已签到的记录应通过审核流程处理。") }
                Section("对标状态") { Text("当前依据 Luma 的公开界面与功能资料实现活动流程，未逐页核实原生应用的全部交互。生日是本版本的选填资料字段，不代表已确认 Luma 存在相同页面。") }
                Section { LabeledContent("版本", value: "0.1.0 · iOS 本机体验") }
            }.font(.subheadline).navigationTitle("服务说明与隐私").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct SavedEventsView: View {
    @Environment(AppStore.self) private var store
    @State private var selected: CampusEvent?
    var body: some View { List { let items = store.events.filter { store.state.favorites.contains($0.id) }; if items.isEmpty { EmptyState(symbol: "bookmark", title: "收藏喜欢的活动", subtitle: "在活动详情页点一下收藏，就可以在这里找到。") }; ForEach(items) { event in Button { selected = event } label: { EventRow(event: event) }.buttonStyle(.plain) } }.navigationTitle("收藏的活动").sheet(item: $selected) { EventDetailView(eventID: $0.id) } }
}
struct FollowedHostsView: View {
    @Environment(AppStore.self) private var store
    var body: some View { List { if store.state.followedHosts.isEmpty { EmptyState(symbol: "person.2", title: "找到你的校园同好", subtitle: "关注组织，随时查看他们的活动。") }; ForEach(store.state.followedHosts.sorted(), id: \.self) { host in NavigationLink { HostView(host: host) } label: { HStack { HostAvatar(name: host); Text(host).font(.subheadline) } } } }.navigationTitle("关注的组织") }
}
struct CreditsView: View {
    @Environment(AppStore.self) private var store
    var credits: [Registration] { store.state.registrations.filter { $0.studentID == store.profile.id && $0.status == .checkedIn && $0.creditHundredths > 0 } }
    var body: some View {
        List {
            Section {
                HStack { VStack(alignment: .leading, spacing: 10) { Text("本机综测记录").font(.caption).foregroundStyle(.secondary); Text(String(format: "%.2f", Double(credits.filter(\.creditApproved).reduce(0) { $0 + $1.creditHundredths }) / 100)).font(.system(size: 45, weight: .bold, design: .rounded)); Text("已审核计入").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "seal.fill").font(.system(size: 45)).foregroundStyle(Color.accentGreen.opacity(0.25)) }.padding(.vertical, 15)
            }
            Section("活动明细") {
                if credits.isEmpty { EmptyState(symbol: "seal", title: "每一次参与，都值得记录", subtitle: "完成签到后，活动综测记录会显示在这里。") }
                ForEach(credits) { credit in HStack { VStack(alignment: .leading, spacing: 8) { Text(store.event(credit.eventID)?.title ?? "活动").font(.subheadline.bold()); Tag(text: credit.creditApproved ? "已计入" : "待审核", color: credit.creditApproved ? .accentGreen : .orange) }; Spacer(); Text(String(format: "+%.2f", Double(credit.creditHundredths) / 100)).font(.headline) } }
            }
        }.navigationTitle("我的综测").navigationBarTitleDisplayMode(.inline)
    }
}
