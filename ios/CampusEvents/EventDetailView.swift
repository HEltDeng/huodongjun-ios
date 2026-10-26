import SwiftUI
import CoreImage.CIFilterBuiltins
import EventKit
import EventKitUI

struct EventDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var eventID: UUID
    @State private var registrationSheet = false
    @State private var ticket = false
    @State private var group = false
    @State private var calendar = false
    @State private var manage = false
    @State private var schools = false
    @State private var cancel = false
    @State private var media = false
    var body: some View {
        NavigationStack {
            if let event = store.event(eventID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        Button { media = true } label: { Color.clear.aspectRatio(1.22, contentMode: .fit).overlay { EventCover(event: event) }.clipped().clipShape(RoundedRectangle(cornerRadius: 25)).overlay(alignment: .bottomTrailing) { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption.bold()).padding(11).background(.regularMaterial, in: Circle()).padding(13) } }.buttonStyle(SoftPressStyle()).accessibilityLabel("查看活动海报大图")
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Tag(text: event.scopeLabel); Tag(text: event.category.rawValue); if event.space == .campus && event.creditHundredths > 0 { Tag(text: "+\(event.creditText) 综测") }; if event.cancelled { Tag(text: "已取消", color: .red) } }
                            Text(event.title).font(.system(size: 29, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                            Text(event.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                        NavigationLink { HostView(host: event.host) } label: {
                            HStack(spacing: 11) { HostAvatar(name: event.host, size: 40); VStack(alignment: .leading, spacing: 3) { Text("主办方").font(.caption).foregroundStyle(.secondary); Text(event.host).font(.subheadline.weight(.semibold)).foregroundStyle(.primary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                        }
                        Divider()
                        VStack(spacing: 20) {
                            Button { calendar = true } label: { detailRow(icon: "calendar", title: event.start.formatted(.dateTime.month().day().weekday(.wide)), subtitle: "\(event.start.formatted(.dateTime.hour().minute())) – \(event.end.formatted(.dateTime.hour().minute()))", trailing: "添加日历") }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("detail.calendar")
                            detailRow(icon: "mappin.and.ellipse", title: event.location, subtitle: event.locationContext, trailing: nil)
                            detailRow(icon: "person.crop.rectangle", title: "报名对象", subtitle: event.audienceText, trailing: nil)
                            detailRow(icon: "person.2", title: "\(store.count(event)) 人已报名", subtitle: "限额 \(event.capacity) 人" + (event.requiresApproval ? " · 需要主办方审核" : " · 免费参加"), trailing: nil)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 14) {
                            Text("关于活动").font(.title3.bold())
                            Text(event.description).font(.system(size: 15)).lineSpacing(6).foregroundStyle(Color.primary.opacity(0.8)).textSelection(.enabled)
                        }
                        if !event.agenda.isEmpty {
                            VStack(alignment: .leading, spacing: 15) { Text("活动安排").font(.title3.bold()); ForEach(Array(event.agenda.enumerated()), id: \.offset) { index, line in HStack(alignment: .top, spacing: 13) { Text(String(index + 1)).font(.caption.bold()).foregroundStyle(Color.accentGreen).frame(width: 25, height: 25).background(Color.accentGreen.opacity(0.1), in: Circle()); Text(line).font(.subheadline).padding(.top, 3) } } }
                        }
                        if event.space == .campus && event.creditHundredths > 0 {
                            HStack(alignment: .top, spacing: 13) { Image(systemName: "seal").font(.title2).foregroundStyle(Color.accentGreen); VStack(alignment: .leading, spacing: 5) { Text("活动综测  +\(event.creditText)").font(.subheadline.bold()); Text(event.creditMode.rawValue).font(.caption).foregroundStyle(.secondary) }; Spacer() }.padding(17).background(Color.accentGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        }
                        if SpaceRules.canDiscuss(event, state: store.state) {
                            NavigationLink { DiscussionView(eventID: event.id) } label: { Label("进入活动讨论", systemImage: "bubble.left.and.bubble.right").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 17)) }.buttonStyle(SoftPressStyle())
                        }
                        if event.space == .city { Text("校外活动保留参与记录，综测由所属学校另行认定。").font(.footnote).foregroundStyle(.secondary) }
                        if event.group.available {
                            Button { group = true } label: { HStack(spacing: 13) { Image(systemName: "qrcode").font(.title2).frame(width: 42, height: 42).background(.white, in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 4) { Text(event.group.name).font(.subheadline.bold()); Text(event.group.platform + " · " + (event.group.membersOnly ? "报名成功后可加入" : "点击查看入群方式")).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(15).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(SoftPressStyle()).accessibilityIdentifier("detail.group")
                        }
                        if event.hostID == store.profile.id {
                            Button { manage = true } label: { Label("管理活动", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("detail.manage")
                        }
                        if let reg = store.registration(event.id), reg.status != .checkedIn {
                            Button("取消报名", role: .destructive) { cancel = true }.font(.footnote).frame(maxWidth: .infinity).padding(.top, 5)
                        }
                    }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 24)
                }.background(Color.paper)
                .navigationTitle("活动详情").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 9) {
                        HStack { Text(store.registration(event.id)?.status.rawValue ?? (event.cancelled ? "已取消" : "免费参加")).font(.caption.weight(.semibold)); Spacer(); Text(event.deadline.formatted(.dateTime.month().day().hour().minute()) + " 截止").font(.caption2).foregroundStyle(.secondary) }
                        HStack(spacing: 8) {
                            Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 48) }.buttonStyle(SoftPressStyle()).accessibilityLabel("关闭活动详情")
                            Button { store.favorite(event.id) } label: { Image(systemName: store.state.favorites.contains(event.id) ? "bookmark.fill" : "bookmark").frame(width: 44, height: 48).foregroundStyle(Color.accentGreen) }.buttonStyle(SoftPressStyle()).accessibilityLabel(store.state.favorites.contains(event.id) ? "取消收藏" : "收藏活动").accessibilityIdentifier("detail.favorite")
                            ShareLink(item: event.shareText) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 48) }.buttonStyle(SoftPressStyle()).accessibilityLabel("分享活动")
                            Button {
                                if !store.eligible(event) { schools = true }
                                else if let reg = store.registration(event.id), [.confirmed, .checkedIn].contains(reg.status) { ticket = true }
                                else { registrationSheet = true }
                            } label: { Text(cta(event)).frame(maxWidth: .infinity).lineLimit(2).minimumScaleFactor(0.8) }.buttonStyle(PrimaryButton())
                                .disabled((!store.eligible(event) && !SpaceRules.verifiedSchools(store.state).isEmpty) || event.cancelled || (store.registration(event.id) == nil && event.deadline <= Date()) || [.pending, .waitlisted].contains(store.registration(event.id)?.status ?? .cancelled))
                                .accessibilityIdentifier("detail.register")
                        }
                    }.padding(.horizontal, 18).padding(.vertical, 11).background(.regularMaterial)
                }
                .fullScreenCover(isPresented: $media) { if let image = event.imageData.flatMap({ UIImage(data: $0) }) ?? UIImage(named: event.cover) { MediaLightbox(image: image) } }
                .sheet(isPresented: $registrationSheet) { RegistrationView(eventID: event.id).appSheet() }
                .sheet(isPresented: $ticket) { TicketView(eventID: event.id).appSheet() }
                .sheet(isPresented: $group) { GroupView(eventID: event.id).appSheet(SheetSize.half) }
                .sheet(isPresented: $calendar) { CalendarEditor(event: event).ignoresSafeArea() }
                .sheet(isPresented: $manage) { ManageEventView(eventID: event.id).appSheet(.large, stops: [SheetSize.tall, .large]) }
                .sheet(isPresented: $schools) { SchoolPickerView().appSheet(SheetSize.half) }
                .bottomActions("取消报名后，原入场凭证将失效。", isPresented: $cancel, cancelTitle: "保留报名", actions: [SheetAction("取消报名", role: .destructive) { if let reg = store.registration(event.id) { store.cancel(reg); if store.error == nil { store.notify("已取消报名，原入场凭证已失效") } } }])
            } else { ContentUnavailableView("活动不存在", systemImage: "calendar.badge.exclamationmark") }
        }
    }
    func cta(_ event: CampusEvent) -> String {
        if event.cancelled { return "活动已取消" }
        if !store.eligible(event) { return SpaceRules.verifiedSchools(store.state).isEmpty ? "验证身份后报名" : "限指定高校报名" }
        if let reg = store.registration(event.id) { switch reg.status { case .confirmed, .checkedIn: return "查看入场凭证"; case .pending: return "等待审核"; case .waitlisted: return "已加入候补"; case .cancelled: break } }
        if event.deadline <= Date() { return "报名已截止" }
        if store.count(event) >= event.capacity { return event.allowWaitlist ? "加入候补" : "名额已满" }
        return "报名参加"
    }
    func detailRow(icon: String, title: String, subtitle: String, trailing: String?) -> some View {
        HStack(alignment: .center, spacing: 13) { Image(systemName: icon).font(.system(size: 21, weight: .light)).foregroundStyle(.secondary).frame(width: 38, height: 42).overlay(RoundedRectangle(cornerRadius: 11).stroke(.gray.opacity(0.2))); VStack(alignment: .leading, spacing: 5) { Text(title).font(.subheadline.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }; Spacer(minLength: 0); if let trailing { Text(trailing).font(.caption).foregroundStyle(Color.accentGreen) } }
    }
}

struct RegistrationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var eventID: UUID
    @State private var name = ""
    @State private var agreed = false
    @State private var attempted = false
    @State private var success = false
    @State private var service = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            if let event = store.event(eventID) {
                if success {
                    VStack(spacing: 22) {
                        Spacer(minLength: 20)
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 58)).foregroundStyle(Color.accentGreen)
                        Text(store.registration(eventID)?.status.rawValue ?? "已提交报名").font(.title.bold())
                        Text(event.title).font(.headline).multilineTextAlignment(.center)
                        Text(event.start.formatted(date: .complete, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                        if let reg = store.registration(eventID), reg.status == .confirmed { TicketCode(code: "huodongjun:local-ticket:\(reg.ticketCode)").frame(width: 180, height: 180) }
                        Spacer(minLength: 20)
                        Button { dismiss() } label: { Text("完成").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("registration.done")
                    }.padding(24).background(Color.paper)
                } else {
                    Form {
                        Section { HStack(spacing: 14) { EventCover(event: event).frame(width: 65, height: 65).clipped().clipShape(RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading, spacing: 7) { Text(event.title).font(.headline); Text(event.start.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) } } }
                        Section("报名信息") {
                            VStack(alignment: .leading) { TextField("姓名", text: $name).textContentType(.name).accessibilityIdentifier("registration.name"); InlineAlert(message: attempted ? FormValidation.required(name, title: "姓名") : nil) }
                            let membership = SpaceRules.membership(for: event, state: store.state)
                            LabeledContent("学校", value: membership.map { School.named($0.schoolID).name } ?? "待验证")
                            LabeledContent("学号", value: membership?.studentNumber ?? "待验证")
                            LabeledContent("学院", value: membership?.college ?? "待验证")
                        }
                        Section {
                            Toggle("确认报名信息，并同意服务说明", isOn: $agreed).font(.subheadline)
                            InlineAlert(message: attempted && !agreed ? "请先确认报名信息并阅读服务说明" : nil)
                            Button("查看服务说明") { service = true }
                        }
                    }.scrollContentBackground(.hidden).background(Color.paper).navigationTitle("报名活动").navigationBarTitleDisplayMode(.inline)
                        .safeAreaInset(edge: .bottom) {
                            VStack(spacing: 10) {
                                InlineAlert(message: error)
                                CompletionButton(title: "确认报名", symbol: "ticket", action: {
                                    attempted = true
                                    guard agreed, FormValidation.required(name, title: "姓名") == nil else { return false }
                                    let ok = store.update { $0.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); $0.consented = true } && store.register(event)
                                    if !ok { error = store.error; store.error = nil }; return ok
                                }, completed: { success = true }).accessibilityIdentifier("registration.submit")
                                Button("取消") { dismiss() }.buttonStyle(QuietButton())
                            }.padding(20).background(.regularMaterial)
                        }
                        .onAppear { name = store.profile.name }
                        .sheet(isPresented: $service) { ServiceInfoView().appSheet() }
                }
            }
        }
    }
}

struct TicketCode: View {
    var code: String
    var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(code.utf8)
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), from: output.extent.applying(CGAffineTransform(scaleX: 10, y: 10))) else { return nil }
        return UIImage(cgImage: cg)
    }
    var body: some View { if let image { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("入场二维码") } }
}
struct TicketView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var eventID: UUID
    @State private var copied = false
    var body: some View {
        NavigationStack {
            if let event = store.event(eventID), let reg = store.registration(eventID) {
                ScrollView {
                    VStack(spacing: 24) {
                        EventCover(event: event).frame(height: 175).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
                        VStack(spacing: 10) { Text(event.title).font(.title2.bold()).multilineTextAlignment(.center); Text(event.start.formatted(date: .complete, time: .shortened)).font(.subheadline).foregroundStyle(.secondary); Text(event.location).font(.caption).foregroundStyle(.secondary) }
                        Divider()
                        if [.confirmed, .checkedIn].contains(reg.status) { TicketCode(code: "huodongjun:local-ticket:\(reg.ticketCode)").frame(width: 225, height: 225) }
                        Tag(text: reg.status.rawValue)
                        Text(store.profile.name).font(.headline)
                        Text("本机体验票 · 仅用于功能联调").font(.caption).foregroundStyle(.secondary)
                        Button(copied ? "已复制核销码" : "复制核销码") { UIPasteboard.general.string = "huodongjun:local-ticket:\(reg.ticketCode)"; copied = true; store.notify("核销码已复制") }.font(.footnote)
                        if event.group.available { NavigationLink { GroupContent(eventID: eventID) } label: { Label("进入活动群", systemImage: "person.2").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()) }
                    }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 25)).padding(22)
                }.background(Color.paper).navigationTitle("入场凭证").navigationBarTitleDisplayMode(.inline).bottomDismiss()
            }
        }
    }
}

struct CalendarEditor: UIViewControllerRepresentable {
    let event: CampusEvent
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        let eventStore = EKEventStore()
        let item = EKEvent(eventStore: eventStore)
        item.title = event.title; item.startDate = event.start; item.endDate = event.end; item.location = event.location; item.notes = event.description
        controller.eventStore = eventStore; controller.event = item; controller.editViewDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}
    class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) { dismiss() }
    }
}
