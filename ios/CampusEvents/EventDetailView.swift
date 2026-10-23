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
    @State private var cancel = false
    var body: some View {
        NavigationStack {
            if let event = store.event(eventID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        EventCover(event: event).aspectRatio(1, contentMode: .fit).clipped().clipShape(RoundedRectangle(cornerRadius: 25))
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Tag(text: event.category.rawValue); if event.creditHundredths > 0 { Tag(text: "+\(event.creditText) 综测") }; if event.cancelled { Tag(text: "已取消", color: .red) } }
                            Text(event.title).font(.system(size: 29, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                            Text(event.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                        NavigationLink { HostView(host: event.host) } label: {
                            HStack(spacing: 11) { HostAvatar(name: event.host, size: 40); VStack(alignment: .leading, spacing: 3) { Text("主办方").font(.caption).foregroundStyle(.secondary); Text(event.host).font(.subheadline.weight(.semibold)).foregroundStyle(.primary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                        }
                        Divider()
                        VStack(spacing: 20) {
                            Button { calendar = true } label: { detailRow(icon: "calendar", title: event.start.formatted(.dateTime.month().day().weekday(.wide)), subtitle: "\(event.start.formatted(.dateTime.hour().minute())) – \(event.end.formatted(.dateTime.hour().minute()))", trailing: "添加日历") }.buttonStyle(.plain).accessibilityIdentifier("detail.calendar")
                            detailRow(icon: "mappin.and.ellipse", title: event.location, subtitle: "长沙理工大学 · \(event.campus.rawValue)", trailing: nil)
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
                        if event.creditHundredths > 0 {
                            HStack(alignment: .top, spacing: 13) { Image(systemName: "seal").font(.title2).foregroundStyle(Color.accentGreen); VStack(alignment: .leading, spacing: 5) { Text("活动综测  +\(event.creditText)").font(.subheadline.bold()); Text(event.creditMode.rawValue).font(.caption).foregroundStyle(.secondary) }; Spacer() }.padding(17).background(Color.accentGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        }
                        if event.group.available {
                            Button { group = true } label: { HStack(spacing: 13) { Image(systemName: "qrcode").font(.title2).frame(width: 42, height: 42).background(.white, in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 4) { Text(event.group.name).font(.subheadline.bold()); Text(event.group.platform + " · " + (event.group.membersOnly ? "报名成功后可加入" : "点击查看入群方式")).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(15).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(.plain).accessibilityIdentifier("detail.group")
                        }
                        if event.hostID == store.profile.id {
                            Button { manage = true } label: { Label("管理活动", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("detail.manage")
                        }
                        if let reg = store.registration(event.id), reg.status != .checkedIn {
                            Button("取消报名", role: .destructive) { cancel = true }.font(.footnote).frame(maxWidth: .infinity).padding(.top, 5)
                        }
                    }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 24)
                }.background(Color.paper)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("关闭活动详情") }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { store.favorite(event.id) } label: { Image(systemName: store.state.favorites.contains(event.id) ? "bookmark.fill" : "bookmark") }.accessibilityLabel(store.state.favorites.contains(event.id) ? "取消收藏" : "收藏活动").accessibilityIdentifier("detail.favorite")
                        ShareLink(item: event.shareText) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("分享活动")
                    }
                }.navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) { Text(store.registration(event.id)?.status.rawValue ?? (event.cancelled ? "已取消" : "免费参加")).font(.subheadline.bold()); Text(event.deadline.formatted(.dateTime.month().day().hour().minute()) + " 截止").font(.caption2).foregroundStyle(.secondary) }
                        Spacer(minLength: 0)
                        Button {
                            if let reg = store.registration(event.id), [.confirmed, .checkedIn].contains(reg.status) { ticket = true }
                            else { registrationSheet = true }
                        } label: { Text(cta(event)).frame(minWidth: 105) }.buttonStyle(PrimaryButton())
                            .disabled(event.cancelled || (store.registration(event.id) == nil && event.deadline <= Date()) || [.pending, .waitlisted].contains(store.registration(event.id)?.status ?? .cancelled))
                            .accessibilityIdentifier("detail.register")
                    }.padding(.horizontal, 22).padding(.vertical, 13).background(.regularMaterial)
                }
                .sheet(isPresented: $registrationSheet) { RegistrationView(eventID: event.id) }
                .sheet(isPresented: $ticket) { TicketView(eventID: event.id) }
                .sheet(isPresented: $group) { GroupView(eventID: event.id) }
                .sheet(isPresented: $calendar) { CalendarEditor(event: event).ignoresSafeArea() }
                .sheet(isPresented: $manage) { ManageEventView(eventID: event.id) }
                .confirmationDialog("确定取消这场活动的报名？", isPresented: $cancel, titleVisibility: .visible) { Button("取消报名", role: .destructive) { if let reg = store.registration(event.id) { store.cancel(reg) } } }
            } else { ContentUnavailableView("活动不存在", systemImage: "calendar.badge.exclamationmark") }
        }
    }
    func cta(_ event: CampusEvent) -> String {
        if event.cancelled { return "活动已取消" }
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
    @State private var number = ""
    @State private var college = ""
    @State private var agreed = false
    @State private var success = false
    @State private var service = false
    var body: some View {
        NavigationStack {
            if let event = store.event(eventID) {
                if success {
                    VStack(spacing: 23) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 62)).foregroundStyle(Color.accentGreen)
                        Text(store.registration(eventID)?.status.rawValue ?? "已提交报名").font(.title.bold())
                        Text(event.title).font(.headline).multilineTextAlignment(.center)
                        Text(event.start.formatted(date: .complete, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                        if let reg = store.registration(eventID), reg.status == .confirmed { TicketCode(code: "huodongjun:local-ticket:\(reg.ticketCode)").frame(width: 180, height: 180); Text("本机体验票").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button { dismiss() } label: { Text("完成").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("registration.done")
                    }.padding(28).background(Color.paper)
                } else {
                    Form {
                        Section { HStack(spacing: 14) { EventCover(event: event).frame(width: 65, height: 65).clipped().clipShape(RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 7) { Text(event.title).font(.headline); Text(event.start.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) } } }
                        Section("报名信息") {
                            TextField("姓名", text: $name).textContentType(.name).accessibilityIdentifier("registration.name")
                            TextField("学号", text: $number).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("registration.number")
                            TextField("学院", text: $college).accessibilityIdentifier("registration.college")
                        }
                        Section {
                            Toggle("确认报名信息，并同意服务说明", isOn: $agreed).font(.subheadline)
                            Button("查看服务说明") { service = true }
                        }
                        Section {
                            Button {
                                guard agreed else { return }
                                if store.update({ $0.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); $0.profile.studentNumber = number.trimmingCharacters(in: .whitespacesAndNewlines); $0.profile.college = college.trimmingCharacters(in: .whitespacesAndNewlines); $0.consented = true }), store.register(event) { success = true }
                            } label: { Text("确认报名").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).listRowBackground(Color.clear).listRowInsets(EdgeInsets()).disabled(!agreed || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || college.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("registration.submit")
                        }
                    }.navigationTitle("报名活动").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } } }
                    .onAppear { name = store.profile.name; number = store.profile.studentNumber; college = store.profile.college }
                    .sheet(isPresented: $service) { ServiceInfoView() }
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
                        Button(copied ? "已复制核销码" : "复制核销码") { UIPasteboard.general.string = "huodongjun:local-ticket:\(reg.ticketCode)"; copied = true }.font(.footnote)
                        if event.group.available { NavigationLink { GroupContent(eventID: eventID) } label: { Label("进入活动群", systemImage: "person.2").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()) }
                    }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 25)).padding(22)
                }.background(Color.paper).navigationTitle("入场凭证").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
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
