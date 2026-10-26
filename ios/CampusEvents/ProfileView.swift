import SwiftUI
import PhotosUI
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var identity = false
    @State private var schools = false
    @State private var interests = false
    @State private var path = NavigationPath()
    @State private var service = false
    @State private var exit = false
    @State private var notice: String?
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section { SpaceSwitcher().listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) { ProfileAvatar(profile: store.profile, size: 72); Spacer(); Button("编辑资料") { identity = true }.font(.caption.weight(.medium)).buttonStyle(.bordered).clipShape(Capsule()) }
                        Text(store.profile.name).font(.title.bold())
                        Text(store.profile.bio).font(.subheadline).foregroundStyle(.secondary)
                        HStack { Label(store.school.name, systemImage: "building.columns"); Spacer(); Text(store.profile.college).lineLimit(1) }.font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 9).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                Section {
                    NavigationLink { CreditsView() } label: { Label(store.space == .campus ? "本校综测" : "校外参与记录", systemImage: "seal") }
                    NavigationLink { SavedEventsView() } label: { Label("收藏的活动", systemImage: "bookmark") }
                    NavigationLink { FollowedHostsView() } label: { Label("关注的组织", systemImage: "person.2") }
                    NavigationLink { HostDashboard() } label: { Label("主办方工作台", systemImage: "rectangle.stack") }
                }
                Section("账号与偏好") {
                    Button { schools = true } label: { Label("学校与身份", systemImage: "person.text.rectangle") }
                    Button { interests = true } label: { Label("兴趣偏好", systemImage: "sparkles") }
                    NavigationLink { RecommendationSettingsView() } label: { Label("推荐提醒", systemImage: "bell.badge") }
                    Button { Task {
                        do {
                            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                            notice = granted ? "已允许通知。远程活动提醒将在服务端接入后启用。" : "通知权限未开启，可前往系统设置修改。"
                        } catch { notice = "暂时无法请求通知权限。" }
                    } } label: { Label("通知设置", systemImage: "bell") }
                    Button { NotificationCenter.default.post(name: .showInteractionTour, object: nil) } label: { Label("操作引导", systemImage: "hand.point.up.left") }
                    Button { service = true } label: { Label("服务说明与隐私", systemImage: "hand.raised") }
                    if let notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
                    NavigationLink { LocalAdminView() } label: { Label("本机管理预览", systemImage: "slider.horizontal.3") }
                }
                Section { Button("返回欢迎页") { exit = true }.frame(maxWidth: .infinity).foregroundStyle(.secondary) }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $schools) { SchoolPickerView().appSheet(SheetSize.half) }.sheet(isPresented: $interests) { InterestSelectionView().appSheet() }
                .onChange(of: store.contextID) { _, _ in path = NavigationPath() }
                .sheet(isPresented: $identity) { IdentityEditor().appSheet() }.sheet(isPresented: $service) { ServiceInfoView().appSheet() }
                .bottomActions("返回欢迎页？本机活动和报名记录会保留。", isPresented: $exit, actions: [SheetAction("返回欢迎页") { store.update { $0.onboarded = false; $0.settings.setupCompleted = false } }])
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
    @State private var attempted = false
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        MediaPickerButton(data: $profile.avatarData) {
                            ProfileAvatar(profile: profile, size: 76).overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill").font(.caption).foregroundStyle(.white).padding(7).background(Color.ink, in: Circle())
                            }
                        }.accessibilityLabel("设置头像")
                        if isOnboarding { Text("很高兴在这里遇见你").font(.title2.bold()) }
                    }.frame(maxWidth: .infinity).padding(.vertical, 16).listRowBackground(Color.clear)
                }
                Section("个人资料") {
                    VStack(alignment: .leading) {
                        TextField("姓名 / 昵称", text: $profile.name).accessibilityIdentifier("identity.name")
                        InlineAlert(message: attempted ? FormValidation.required(profile.name, title: "姓名或昵称") : nil)
                    }
                    TextField("个人简介", text: $profile.bio, axis: .vertical).lineLimit(2...4)
                    Toggle("添加生日（选填）", isOn: $birthdayEnabled)
                    if birthdayEnabled { DateWheelRow(title: "生日", value: $birthday, upper: Date(), dateOnly: true) }
                }
                Section("校园身份") {
                    LabeledContent("学校", value: School.named(profile.schoolID).name)
                    LabeledContent("绑定学号", value: profile.studentNumber)
                    LabeledContent("学院", value: profile.college)
                }
                Section {
                    Toggle("我已阅读并同意服务说明与隐私", isOn: $consent).font(.subheadline).accessibilityIdentifier("identity.consent")
                    InlineAlert(message: attempted && !consent ? "请阅读并确认服务说明与隐私" : nil)
                    Button("查看服务说明与隐私") { service = true }
                }
            }.scrollContentBackground(.hidden).background(Color.paper)
                .navigationTitle(isOnboarding ? "设置个人资料" : "编辑资料").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        InlineAlert(message: failure)
                        CompletionButton(title: isOnboarding ? "进入活动君" : "保存资料", action: save, completed: {
                            if isOnboarding && !store.update({ $0.onboarded = true }) { return }
                            dismiss()
                        }).accessibilityIdentifier("identity.save")
                        Button("取消") { dismiss() }.buttonStyle(QuietButton())
                    }.padding(.horizontal, 22).padding(.vertical, 10).background(.regularMaterial)
                }
                .onAppear { profile = store.profile; consent = isOnboarding ? true : store.state.consented; birthdayEnabled = profile.birthday != nil; birthday = profile.birthday ?? birthday }
                .sheet(isPresented: $service) { ServiceInfoView().appSheet() }
        }
    }
    func save() -> Bool {
        attempted = true
        guard FormValidation.required(profile.name, title: "姓名或昵称") == nil, consent else { return false }
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.birthday = birthdayEnabled ? birthday : nil
        let success = store.update { $0.profile = profile; $0.consented = consent }
        failure = success ? nil : store.error; store.error = nil
        return success
    }
}

struct ServiceInfoView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("关于当前版本") { Text("活动君包含校园与长沙两个独立活动空间。当前为本机开发体验版，示例活动并非学校正式发布。所有创建、报名、聊天、核销和计分操作只影响当前设备，尚未与学校系统或其他同学同步。") }
                Section("身份与综测") { Text("学校验证当前仅为明确标识的本机演示；学号绑定不代表真实认证。正式版本必须由校方渠道验证并由服务端执行学校、报名范围和群权限检查。二维码是联调凭证，综测记录用于流程体验，不作为学校正式综测成绩。正式发布前将接入身份校验、教师权限、签名核销和审核记录。") }
                Section("双空间与兴趣") { Text("每所学校的内部活动独立，未验证不可访问。跨校活动属于长沙空间，可指定报名学校；参加跨校活动不会获得主办学校的校内权限。兴趣用于可报名活动的排序。本机精选和本地通知可体验，学校实时发布和远程推送尚未接入。跨校签到只记录参与，不自动增加本校综测。") }
                Section("数据与权限") { Text("资料、选填生日、报名记录和主动选择的图片保存在应用沙盒内。照片选择使用系统选择器；保存二维码时才请求添加照片权限；扫码或拍照时才请求相机权限。用户主动打开群链接或外部应用后，目标服务按其自身规则处理数据。") }
                Section("使用约定") { Text("发布活动请确保内容和图片可以使用；不要冒充校方或主办方。不要发布他人的学号、联系方式和未经许可的群二维码。取消活动需明确确认，已签到的记录应通过审核流程处理。") }
                Section("对标状态") { Text("当前依据 Luma 的公开界面与功能资料实现活动流程，未逐页核实原生应用的全部交互。生日是本版本的选填资料字段，不代表已确认 Luma 存在相同页面。") }
                Section { LabeledContent("版本", value: "0.3.0 · 交互精修本机体验") }
            }.font(.subheadline).navigationTitle("服务说明与隐私").navigationBarTitleDisplayMode(.inline).bottomDismiss()
        }
    }
}

struct SavedEventsView: View {
    @Environment(AppStore.self) private var store
    @State private var selected: CampusEvent?
    var body: some View { List { let items = store.events.filter { store.state.favorites.contains($0.id) }; if items.isEmpty { EmptyState(symbol: "bookmark", title: "收藏喜欢的活动", subtitle: "在活动详情页点一下收藏，就可以在这里找到。") }; ForEach(items) { event in Button { selected = event } label: { EventRow(event: event) }.buttonStyle(SoftPressStyle()) } }.navigationTitle("收藏的活动").sheet(item: $selected) { EventDetailView(eventID: $0.id).appSheet() } }
}
struct FollowedHostsView: View {
    @Environment(AppStore.self) private var store
    var body: some View { List { if store.state.followedHosts.isEmpty { EmptyState(symbol: "person.2", title: "找到你的校园同好", subtitle: "关注组织，随时查看他们的活动。") }; ForEach(store.state.followedHosts.sorted(), id: \.self) { host in NavigationLink { HostView(host: host) } label: { HStack { HostAvatar(name: host); Text(host).font(.subheadline) } } } }.navigationTitle("关注的组织") }
}
struct CreditsView: View {
    @Environment(AppStore.self) private var store
    var credits: [Registration] { store.state.registrations.filter { $0.studentID == store.profile.id && $0.status == .checkedIn && store.event($0.eventID) != nil && (store.space == .city || $0.creditHundredths > 0) } }
    var body: some View {
        List {
            Section {
                HStack { VStack(alignment: .leading, spacing: 10) { Text(store.space == .campus ? store.school.name + " · 综测记录" : "长沙 · 参与记录").font(.caption).foregroundStyle(.secondary); Text(store.space == .city ? "\(credits.count)" : String(format: "%.2f", Double(credits.filter(\.creditApproved).reduce(0) { $0 + $1.creditHundredths }) / 100)).font(.system(size: 45, weight: .bold, design: .rounded)); Text(store.space == .campus ? "已审核计入" : "已签到活动").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "seal.fill").font(.system(size: 45)).foregroundStyle(Color.accentGreen.opacity(0.25)) }.padding(.vertical, 15)
            }
            Section("活动明细") {
                if credits.isEmpty { EmptyState(symbol: "seal", title: "每一次参与，都值得记录", subtitle: store.space == .campus ? "完成签到后，活动综测记录会显示在这里。" : "完成签到后，你参加的长沙活动会显示在这里。") }
                ForEach(credits) { credit in HStack { VStack(alignment: .leading, spacing: 8) { Text(store.event(credit.eventID)?.title ?? "活动").font(.subheadline.bold()); Tag(text: store.space == .city ? "已参加" : credit.creditApproved ? "已计入" : "待审核", color: credit.creditApproved ? .accentGreen : .orange) }; Spacer(); if store.space == .campus { Text(String(format: "+%.2f", Double(credit.creditHundredths) / 100)).font(.headline) } } }
            }
        }.navigationTitle(store.space == .campus ? "本校综测" : "校外参与记录").navigationBarTitleDisplayMode(.inline)
    }
}
