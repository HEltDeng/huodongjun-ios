import SwiftUI
import PhotosUI
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var identity = false
    @State private var schools = false
    @State private var interests = false
    @State private var settings = false
    @State private var path = NavigationPath()
    private var joined: Int { store.scopedEvents.filter { store.registration($0.id) != nil }.count }
    private var saved: Int { store.events.filter { store.state.favorites.contains($0.id) }.count }
    private var hosted: Int { store.scopedEvents.filter { $0.hostID == store.profile.id }.count }
    private var credits: [Registration] { store.state.registrations.filter { $0.studentID == store.profile.id && $0.status == .checkedIn && store.event($0.eventID) != nil } }
    private var points: String { String(format: "%.2f", Double(credits.filter(\.creditApproved).reduce(0) { $0 + $1.creditHundredths }) / 100) }
    private var member: SchoolMembership? { store.state.settings.memberships.first { $0.schoolID == store.school.id } }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("我的").font(.system(size: 30, weight: .bold)).foregroundStyle(Color.ink)
                        Spacer()
                        Button { settings = true } label: {
                            Image(systemName: "gearshape").font(.system(size: 21, weight: .medium)).frame(width: 46, height: 46).background(.white, in: Circle())
                        }.buttonStyle(SoftPressStyle()).accessibilityLabel("设置").accessibilityIdentifier("profile.settings")
                    }
                    SpaceSwitcher()
                    identityCard
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("我的常用").font(.headline)
                            Spacer()
                            Text(store.space == .campus ? "校园生活" : "长沙生活").font(.caption).foregroundStyle(.secondary)
                        }
                        quickActions
                    }
                    VStack(spacing: 0) {
                        NavigationLink { FollowedHostsView().toolbar(.visible, for: .navigationBar) } label: {
                            ProfileMenuRow(title: "关注的组织", symbol: "person.2", value: "\(store.state.followedHosts.count)")
                        }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.following")
                        Divider().padding(.leading, 58).padding(.trailing, 18)
                        NavigationLink { RecommendationSettingsView().toolbar(.visible, for: .navigationBar) } label: {
                            ProfileMenuRow(title: "推荐提醒", symbol: "bell.badge", value: "偏好设置")
                        }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.recommendations")
                    }.background(.white, in: RoundedRectangle(cornerRadius: 23))
                }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 24)
            }.background(Color.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $schools) { SchoolPickerView().appSheet(SheetSize.half) }
                .sheet(isPresented: $interests) { InterestSelectionView().appSheet() }
                .sheet(isPresented: $identity) { IdentityEditor().appSheet() }
                .sheet(isPresented: $settings) { ProfileSettingsView().appSheet() }
                .onChange(of: store.contextID) { _, _ in path = NavigationPath() }
        }
    }
    private var identityCard: some View {
        VStack(spacing: 17) {
            Button { identity = true } label: {
                HStack(spacing: 14) {
                    ProfileAvatar(profile: store.profile, size: 62)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(store.profile.name).font(.title2.bold()).foregroundStyle(Color.ink).lineLimit(2)
                        if !store.profile.bio.isEmpty { Text(store.profile.bio).font(.subheadline).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.pencil").font(.system(size: 19, weight: .medium))
                        Text("编辑").font(.caption.weight(.medium))
                    }.foregroundStyle(Color.accentGreen).frame(width: 46, height: 50).background(Color.accentGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                }.contentShape(Rectangle())
            }.buttonStyle(SoftPressStyle()).accessibilityLabel("编辑资料，" + store.profile.name).accessibilityIdentifier("profile.edit")
            Divider().overlay(Color.accentGreen.opacity(0.03))
            Button { schools = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "building.columns").font(.system(size: 18)).foregroundStyle(Color.accentGreen).frame(width: 24)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.school.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink)
                        Text(member?.college ?? "完善学校身份").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(member?.status.rawValue ?? "去验证").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.accentGreen).padding(.horizontal, 8).padding(.vertical, 6).background(Color.accentGreen.opacity(0.07), in: Capsule())
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.schoolCard")
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.accentGreen.opacity(0.055), lineWidth: 1))
    }
    private var quickActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 10) {
            Button { NotificationCenter.default.post(name: .openMyActivities, object: nil) } label: {
                ProfileShortcut(title: "我的活动", symbol: "calendar", detail: "\(joined) 场报名", emphasized: true)
            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.activities")
            NavigationLink { SavedEventsView().toolbar(.visible, for: .navigationBar) } label: {
                ProfileShortcut(title: "我的收藏", symbol: "bookmark", detail: "\(saved) 场活动")
            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.saved")
            NavigationLink { CreditsView().toolbar(.visible, for: .navigationBar) } label: {
                ProfileShortcut(title: store.space == .campus ? "综测记录" : "参与记录", symbol: "seal", detail: store.space == .campus ? points + " 分已计入" : "\(credits.count) 次签到")
            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.credits")
            Button { interests = true } label: {
                ProfileShortcut(title: "兴趣偏好", symbol: "sparkles", detail: "已选 \(store.state.settings.interests.count) 个方向")
            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.interests")
            Button { schools = true } label: {
                ProfileShortcut(title: "学校身份", symbol: "person.text.rectangle", detail: member?.status.rawValue ?? "待验证")
            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.schools")
            NavigationLink { HostDashboard().toolbar(.visible, for: .navigationBar) } label: {
                ProfileShortcut(title: "主办工作台", symbol: "rectangle.stack", detail: "\(hosted) 场活动")
            }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("profile.host")
        }
    }
}
private struct ProfileShortcut: View {
    let title: String
    let symbol: String
    let detail: String
    var emphasized = false
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 24, weight: .regular)).foregroundStyle(Color.accentGreen)
                .frame(width: 43, height: 40).background(Color.accentGreen.opacity(emphasized ? 0.11 : 0.055), in: RoundedRectangle(cornerRadius: 13))
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink).lineLimit(1)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }.padding(.horizontal, 5).padding(.vertical, 13).frame(maxWidth: .infinity, minHeight: 116)
            .background(emphasized ? Color.accentGreen.opacity(0.065) : .white, in: RoundedRectangle(cornerRadius: 21))
            .contentShape(RoundedRectangle(cornerRadius: 21)).accessibilityElement(children: .combine)
    }
}
private struct ProfileMenuRow: View {
    let title: String
    let symbol: String
    var value: String = ""
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 20, weight: .regular)).foregroundStyle(Color.accentGreen).frame(width: 27)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink)
            Spacer()
            Text(value).font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }.padding(.horizontal, 18).frame(minHeight: 58).contentShape(Rectangle())
    }
}
struct ProfileSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var service = false
    @State private var exit = false
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            List {
                Section("通知与帮助") {
                    Button { Task {
                        do {
                            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                            notice = granted ? "已允许通知。远程活动提醒将在服务端接入后启用。" : "通知权限未开启，可前往系统设置修改。"
                        } catch { notice = "暂时无法请求通知权限。" }
                    } } label: { Label("通知设置", systemImage: "bell") }
                    if let notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
                    Button { dismiss(); NotificationCenter.default.post(name: .showInteractionTour, object: nil) } label: { Label("操作引导", systemImage: "hand.point.up.left") }
                    Button { service = true } label: { Label("服务说明与隐私", systemImage: "hand.raised") }
                }
                Section { NavigationLink { LocalAdminView() } label: { Label("本机管理预览", systemImage: "slider.horizontal.3") } }
                Section { Button("返回欢迎页") { exit = true }.frame(maxWidth: .infinity).foregroundStyle(.secondary) }
            }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle("设置").navigationBarTitleDisplayMode(.inline).bottomDismiss()
                .sheet(isPresented: $service) { ServiceInfoView().appSheet() }
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
                Section("官方赛事") { NavigationLink("赛事来源与说明") { CompetitionSourceView() } }
                Section("使用约定") { Text("发布活动请确保内容和图片可以使用；不要冒充校方或主办方。不要发布他人的学号、联系方式和未经许可的群二维码。取消活动需明确确认，已签到的记录应通过审核流程处理。") }
                Section("对标状态") { Text("当前依据 Luma 的公开界面与功能资料实现活动流程，未逐页核实原生应用的全部交互。生日是本版本的选填资料字段，不代表已确认 Luma 存在相同页面。") }
                Section { LabeledContent("版本", value: "0.4.0 · 官方赛事") }
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
