import SwiftUI
import UserNotifications

struct SoftPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.76), value: configuration.isPressed)
    }
}
struct SpaceSwitcher: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ActivitySpace.allCases) { space in
                Button {
                    guard store.space != space else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85)) { store.switchSpace(space) }
                } label: {
                    Label(space.title, systemImage: space.symbol)
                        .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 41)
                        .foregroundStyle(store.space == space ? Color.ink : Color.secondary)
                        .background { if store.space == space { RoundedRectangle(cornerRadius: 13).fill(.white).shadow(color: .black.opacity(0.045), radius: 5, y: 2).matchedGeometryEffect(id: "space", in: selection) } }
                }.buttonStyle(SoftPressStyle()).accessibilityAddTraits(store.space == space ? .isSelected : [])
                    .accessibilityIdentifier("space.\(space.rawValue)")
            }
        }.padding(4).background(Color.accentGreen.opacity(0.065), in: RoundedRectangle(cornerRadius: 17))
            .sensoryFeedback(.selection, trigger: store.space)
    }
}
struct SchoolCard: View {
    let school: School
    var status: VerificationStatus?
    var selected = false
    var body: some View {
        HStack(spacing: 14) {
            Text(school.shortName).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.accentGreen)
                .frame(width: 54, height: 54).background(Color.accentGreen.opacity(0.075), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 7) {
                Text(school.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.ink)
                Text(status?.rawValue ?? "验证本校身份后进入").font(.caption).foregroundStyle(status == .demoVerified ? Color.accentGreen : .secondary)
            }
            Spacer(minLength: 3)
            Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right").font(selected ? .title3 : .caption).foregroundStyle(selected ? Color.accentGreen : Color.secondary)
        }.padding(17).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}
struct SchoolPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var verifying: School?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("找到你的校园").font(.system(size: 29, weight: .bold)).padding(.top, 15)
                    Text("每一所学校，都有自己的活动空间。") .font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 14)
                    ForEach(School.all) { school in
                        Button {
                            if SpaceRules.verifiedSchools(store.state).contains(school.id) { store.selectSchool(school.id); dismiss() }
                            else { verifying = school }
                        } label: { SchoolCard(school: school, status: store.state.settings.memberships.first { $0.schoolID == school.id }?.status, selected: store.school.id == school.id && store.schoolVerified) }
                        .buttonStyle(SoftPressStyle()).accessibilityIdentifier("school.\(school.id)")
                    }
                }.padding(22)
            }.background(Color.paper).navigationTitle("学校与身份").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
                .sheet(item: $verifying) { school in SchoolVerificationView(school: school) { verifying = nil; dismiss() } }
        }
    }
}
struct SchoolVerificationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let school: School
    var completed: () -> Void = {}
    @State private var number = "DEMO2026001"
    @State private var college = "计算机与通信工程学院"
    @State private var submitted = false
    var status: VerificationStatus? { store.state.settings.memberships.first { $0.schoolID == school.id }?.status }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { HostAvatar(name: school.shortName, size: 62); Spacer(); Tag(text: "本机验证演示") }.padding(.top, 12)
                    VStack(alignment: .leading, spacing: 9) { Text(school.name).font(.system(size: 28, weight: .bold)); Text("绑定校园身份，开启本校的活动世界。").font(.subheadline).foregroundStyle(.secondary) }
                    if let status, submitted || status == .pending || status == .rejected {
                        HStack(spacing: 12) {
                            Image(systemName: status == .pending ? "clock" : status == .rejected ? "exclamationmark.circle" : "checkmark.seal").font(.title2)
                            VStack(alignment: .leading, spacing: 5) { Text(status.rawValue).font(.headline); Text(status == .pending ? "审核期间可浏览长沙开放活动。" : status == .rejected ? "请核对学号和学院后重新提交。" : "可以进入这所学校的校园空间。").font(.caption) }
                        }.foregroundStyle(Color.accentGreen).padding(17).frame(maxWidth: .infinity, alignment: .leading).background(Color.accentGreen.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                    VStack(alignment: .leading, spacing: 17) {
                        VStack(alignment: .leading, spacing: 8) { Text("学号").font(.caption).foregroundStyle(.secondary); TextField("填写学号", text: $number).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("verify.number") }
                        Divider()
                        VStack(alignment: .leading, spacing: 8) { Text("学院").font(.caption).foregroundStyle(.secondary); TextField("填写学院", text: $college).accessibilityIdentifier("verify.college") }
                    }.padding(19).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    VStack(spacing: 12) {
                        Button { apply(.demoVerified) } label: { Label(status == .pending ? "模拟审核通过" : "模拟验证通过", systemImage: "checkmark.seal").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("verify.pass")
                        HStack(spacing: 12) {
                            Button("模拟提交审核") { apply(.pending) }.frame(maxWidth: .infinity)
                            Button("模拟未通过") { apply(.rejected) }.frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).controlSize(.large).font(.subheadline)
                    }.disabled(number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || college.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("学校认证服务尚未接入。本页只模拟验证结果，学号不会提交给学校；正式身份须由学校认可的渠道验证。").font(.footnote).foregroundStyle(.secondary).lineSpacing(4)
                }.padding(24)
            }.background(Color.paper).navigationTitle("验证学校身份").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } } }
                .onAppear { if let member = store.state.settings.memberships.first(where: { $0.schoolID == school.id }) { number = member.studentNumber; college = member.college } }
        }
    }
    func apply(_ status: VerificationStatus) {
        if store.verifyDemo(schoolID: school.id, number: number, college: college, status: status) {
            submitted = true
            if status == .demoVerified { completed(); dismiss() }
        }
    }
}
struct InterestSelectionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onboarding = false
    var completed: () -> Void = {}
    @State private var selected = Set<Interest>()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 11) {
                        Text(onboarding ? "最后一步 · 选择兴趣" : "让好活动更懂你").font(.caption.weight(.medium)).foregroundStyle(Color.accentGreen)
                        Text("想遇见什么？").font(.system(size: 32, weight: .bold))
                        Text("选几个喜欢的方向，也可以稍后再选。").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 16)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Interest.allCases) { interest in
                            let chosen = selected.contains(interest)
                            Button {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                                    if chosen { selected.remove(interest) } else { selected.insert(interest) }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 18) {
                                    HStack { Image(systemName: interest.symbol).font(.system(size: 21, weight: .medium)).foregroundStyle(Color.accentGreen); Spacer(); Image(systemName: chosen ? "checkmark.circle.fill" : "circle").font(.system(size: 19)).foregroundStyle(chosen ? Color.accentGreen : Color.gray.opacity(0.25)) }
                                    Text(interest.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                                }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(chosen ? Color.accentGreen.opacity(0.085) : .white, in: RoundedRectangle(cornerRadius: 20))
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(chosen ? Color.accentGreen.opacity(0.45) : .clear, lineWidth: 1))
                            }.buttonStyle(SoftPressStyle()).accessibilityAddTraits(chosen ? .isSelected : []).accessibilityIdentifier("interest.\(interest.rawValue)")
                        }
                    }
                }.padding(.horizontal, 23).padding(.bottom, 22)
            }.background(Color.paper).navigationTitle("兴趣偏好").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { if !onboarding { Button("取消") { dismiss() } } }; ToolbarItem(placement: .topBarTrailing) { Button("跳过") { selected = []; save() } } }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 12) { HStack { Text("已选择 \(selected.count) 个方向").font(.caption).foregroundStyle(.secondary); Spacer(); Text("随时可以修改").font(.caption).foregroundStyle(.secondary) }; Button { save() } label: { Text(onboarding ? "开启校园生活" : "保存兴趣偏好").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("interests.save") }.padding(.horizontal, 23).padding(.vertical, 16).background(.regularMaterial)
                }
                .onAppear { selected = store.state.settings.interests }
                .sensoryFeedback(.selection, trigger: selected)
        }
    }
    func save() {
        if store.update({ $0.settings.interests = selected; if onboarding { $0.settings.setupCompleted = true } }) { completed(); dismiss() }
    }
}
struct SpaceOnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var verifying: School?
    @State private var interests = false
    var body: some View {
        if interests { InterestSelectionView(onboarding: true) }
        else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("欢迎来到活动君").font(.caption.weight(.medium)).foregroundStyle(Color.accentGreen).padding(.top, 30)
                        Text("先找到\n你的校园。").font(.system(size: 38, weight: .bold)).lineSpacing(3)
                        Text("在校园里相聚，也去长沙遇见新朋友。").font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 20)
                        ForEach(School.all) { school in
                            Button { verifying = school } label: { SchoolCard(school: school, status: store.state.settings.memberships.first { $0.schoolID == school.id }?.status) }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("onboarding.school.\(school.id)")
                        }
                    }.padding(24)
                }.background(Color.paper)
                    .safeAreaInset(edge: .bottom) { Button("先逛逛长沙开放活动") { store.update { $0.settings.activeSpace = .city; $0.settings.setupCompleted = true } }.font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(22).background(.regularMaterial) }
                    .sheet(item: $verifying) { school in SchoolVerificationView(school: school) { verifying = nil; interests = true } }
            }
        }
    }
}
struct CampusAccessPrompt: View {
    @Environment(AppStore.self) private var store
    @State private var schools = false
    var body: some View {
        VStack(spacing: 18) {
            EmptyState(symbol: "building.2.crop.circle", title: "进入你的校园", subtitle: "验证学校身份，解锁本校的活动与讨论。")
            Button { schools = true } label: { Text("选择学校并验证").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton())
            Button("先发现长沙") { store.switchSpace(.city) }.font(.subheadline)
        }.padding(.horizontal, 22).padding(.bottom, 30).sheet(isPresented: $schools) { SchoolPickerView() }
    }
}
struct RecommendationSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var result: String?
    var body: some View {
        Form {
            Section("兴趣相符的新活动") {
                Toggle("校园活动推荐", isOn: Binding(get: { store.state.settings.campusRecommendations }, set: { value in store.update { $0.settings.campusRecommendations = value } }))
                Toggle("长沙跨校活动推荐", isOn: Binding(get: { store.state.settings.cityRecommendations }, set: { value in store.update { $0.settings.cityRecommendations = value } }))
                Picker("频率", selection: Binding(get: { store.state.settings.frequency }, set: { value in store.update { $0.settings.frequency = value } })) { ForEach(RecommendationFrequency.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            }
            Section {
                Button("开启系统推荐提醒") { Task {
                    do {
                        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        RecommendationNotifications.schedule(state: store.state)
                        result = granted ? "已允许通知。本机将按设置在 19:00 提醒你有资格参加的兴趣活动；每周精选在周日发送。" : "通知权限未开启，可在系统设置中修改。"
                    } catch { result = "通知设置暂时不可用。" }
                } }
                Button("预览\(store.space.title)兴趣精选") { let count = store.previewRecommendations(); result = count > 0 ? "已生成 \(count) 条精选，可在\(store.space.title)消息中查看。" : "暂无新的匹配活动。请检查兴趣、学校验证与当前空间的推荐开关；已有精选不会重复生成。" }
            } footer: { Text("报名结果、活动变更和签到提醒独立处理。当前为本机体验，远程新活动推送待接入后台。") }
        }.navigationTitle("推荐提醒").navigationBarTitleDisplayMode(.inline)
            .alert("推荐提醒", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) { Button("知道了") { result = nil } } message: { Text(result ?? "") }
    }
}
